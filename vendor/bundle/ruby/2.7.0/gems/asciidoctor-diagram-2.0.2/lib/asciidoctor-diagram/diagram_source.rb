require_relative 'util/which'

module Asciidoctor
  module Diagram
    # This module describes the duck-typed interface that diagram sources must implement. Implementations
    # may include this module but it is not required.
    module DiagramSource
      def image_name
        raise NotImplementedError.new
      end

      # @return [String] the String representation of the source code for the diagram
      # @abstract
      def code
        raise NotImplementedError.new
      end

      # Get the value for the specified attribute. First look in the attributes on
      # this document and return the value of the attribute if found. Otherwise, if
      # this document is a child of the Document document, look in the attributes of the
      # Document document and return the value of the attribute if found. Otherwise,
      # return the default value, which defaults to nil.
      #
      # @param name [String, Symbol] the name of the attribute to lookup
      # @param default_value [Object] the value to return if the attribute is not found
      # @inherit [Boolean, String] indicates whether to check for the attribute on the AsciiDoctor::Document if not found on this document.
      #                            When a non-nil String is given the an attribute name "#{inherit}-#{name}" is looked for on the document.
      #
      # @return the value of the attribute or the default value if the attribute is not found in the attributes of this node or the document node
      # @abstract
      def attr(name, default_value = nil, inherit = nil)
        raise NotImplementedError.new
      end

      # @return [String] the base directory against which relative paths in this diagram should be resolved
      # @abstract
      def base_dir
        attr('docdir', nil, true) || Dir.pwd
      end

      # Alias for code
      def to_s
        code
      end

      # Determines if the diagram should be regenerated or not. The default implementation of this method simply
      # returns true.
      #
      # @param image_file [String] the path to the previously generated version of the image
      # @param image_metadata [Hash] the image metadata Hash that was stored during the previous diagram generation pass
      # @return [Boolean] true if the diagram should be regenerated; false otherwise
      def should_process?(image_file, image_metadata)
        true
      end

      # Creates an image metadata Hash that will be stored to disk alongside the generated image file. The contents
      # of this Hash are reread during subsequent document processing and then passed to the should_process? method
      # where it can be used to determine if the diagram should be regenerated or not.
      # The default implementation returns an empty Hash.
      # @return [Hash] a Hash containing metadata
      def create_image_metadata
        {}
      end

      def config
        raise NotImplementedError.new
      end

      def find_command(cmd, options = {})
        attr_names = options[:attrs] || options.fetch(:alt_attrs, []) + [cmd]
        cmd_names = [cmd] + options.fetch(:alt_cmds, [])

        cmd_var = 'cmd-' + attr_names[0]

        if config.key? cmd_var
          cmd_path = config[cmd_var]
        else
          cmd_path = attr_names.map { |attr_name| attr(attr_name, nil, true) }.find { |attr| !attr.nil? }

          unless cmd_path && File.executable?(cmd_path)
            cmd_paths = cmd_names.map do |c|
              ::Asciidoctor::Diagram::Which.which(c, :path => options[:path])
            end

            cmd_path = cmd_paths.reject { |c| c.nil? }.first
          end

          config[cmd_var] = cmd_path

          if cmd_path.nil? && options.fetch(:raise_on_error, true)
            raise "Could not find the #{cmd_names.map { |c| "'#{c}'" }.join(', ')} executable in PATH; add it to the PATH or specify its location using the '#{attr_names[0]}' document attribute"
          end
        end

        cmd_path
      end

      def resolve_path target, start = base_dir
        raise NotImplementedError.new
      end
    end

    # Base class for diagram source implementations that uses an md5 checksum of the source code of a diagram to
    # determine if it has been updated or not.
    class BasicSource
      include DiagramSource

      attr_reader :attributes

      def initialize(block_processor, parent_block, attributes)
        @block_processor = block_processor
        @parent_block = parent_block
        @attributes = attributes
      end

      def resolve_path target, start = base_dir
        @parent_block.normalize_system_path(target, start)
      end

      def config
        @block_processor.config
      end

      def image_name
        attr('target', 'diag-' + checksum)
      end

      def attr(name, default_value = nil, inherit = nil)
        name = name.to_s if ::Symbol === name

        value = @attributes[name]

        if value.nil? && inherit
          case inherit
          when String, Symbol
            value = @parent_block.attr("#{inherit.to_s}-#{name}", default_value, true)
          else
            value = @parent_block.attr(name, default_value, inherit)
          end
        end

        value || default_value
      end

      def should_process?(image_file, image_metadata)
        image_metadata[:checksum] != checksum
      end

      def create_image_metadata
        {:checksum => checksum}
      end

      def checksum
        @checksum ||= compute_checksum(code)
      end

      protected

      def resolve_diagram_subs
        if @attributes.key? 'subs'
          @parent_block.resolve_block_subs @attributes['subs'], nil, 'diagram'
        else
          []
        end
      end

      private

      def compute_checksum(code)
        md5 = Digest::MD5.new
        md5 << code
        @attributes.each do |k, v|
          md5 << k.to_s if k
          md5 << v.to_s if v
        end
        md5.hexdigest
      end
    end

    # A diagram source that retrieves the code for the diagram from the contents of a block.
    class ReaderSource < BasicSource
      include DiagramSource

      def initialize(block_processor, parent_block, reader, attributes)
        super(block_processor, parent_block, attributes)
        @reader = reader
      end

      def code
        @code ||= @parent_block.apply_subs(@reader.lines, resolve_diagram_subs).join("\n")
      end
    end

    # A diagram source that retrieves the code for a diagram from an external source file.
    class FileSource < BasicSource
      def initialize(block_processor, parent_block, file_name, attributes)
        super(block_processor, parent_block, attributes)
        @file_name = file_name
      end

      def base_dir
        if @file_name
          File.dirname(@file_name)
        else
          super
        end
      end

      def image_name
        if @attributes['target']
          super
        elsif @file_name
          File.basename(@file_name, File.extname(@file_name))
        else
          checksum
        end
      end

      def should_process?(image_file, image_metadata)
        (@file_name && File.mtime(@file_name) > File.mtime(image_file)) || super
      end

      def code
        @code ||= read_code
      end

      def read_code
        if @file_name
          lines = File.readlines(@file_name)
          lines = prepare_source_array(lines)
          @parent_block.apply_subs(lines, resolve_diagram_subs).join("\n")
        else
          ''
        end
      end

      private

      # Byte arrays for UTF-* Byte Order Marks
      BOM_BYTES_UTF_8 = [0xef, 0xbb, 0xbf]
      BOM_BYTES_UTF_16LE = [0xff, 0xfe]
      BOM_BYTES_UTF_16BE = [0xfe, 0xff]

      # Prepare the source data Array for parsing.
      #
      # Encodes the data to UTF-8, if necessary, and removes any trailing
      # whitespace from every line.
      #
      # If a BOM is found at the beginning of the data, a best attempt is made to
      # encode it to UTF-8 from the specified source encoding.
      #
      # data - the source data Array to prepare (no nil entries allowed)
      #
      # returns a String Array of prepared lines
      def prepare_source_array data
        return [] if data.empty?
        if (leading_2_bytes = (leading_bytes = (first = data[0]).unpack 'C3').slice 0, 2) == BOM_BYTES_UTF_16LE
          data[0] = first.byteslice 2, first.bytesize
          # NOTE you can't split a UTF-16LE string using .lines when encoding is UTF-8; doing so will cause this line to fail
          return data.map {|line| (line.encode ::Encoding::UTF_8, ::Encoding::UTF_16LE).rstrip}
        elsif leading_2_bytes == BOM_BYTES_UTF_16BE
          data[0] = first.byteslice 2, first.bytesize
          return data.map {|line| (line.encode ::Encoding::UTF_8, ::Encoding::UTF_16BE).rstrip}
        elsif leading_bytes == BOM_BYTES_UTF_8
          data[0] = first.byteslice 3, first.bytesize
        end
        if first.encoding == ::Encoding::UTF_8
          data.map {|line| line.rstrip}
        else
          data.map {|line| (line.encode ::Encoding::UTF_8).rstrip}
        end
      end
    end
  end
end