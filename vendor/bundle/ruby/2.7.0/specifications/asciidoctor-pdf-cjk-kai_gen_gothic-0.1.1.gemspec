# -*- encoding: utf-8 -*-
# stub: asciidoctor-pdf-cjk-kai_gen_gothic 0.1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "asciidoctor-pdf-cjk-kai_gen_gothic".freeze
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Rei".freeze]
  s.bindir = "exe".freeze
  s.date = "2015-10-17"
  s.description = "".freeze
  s.email = ["chloerei@gmail.com".freeze]
  s.executables = ["asciidoctor-pdf-cjk-kai_gen_gothic-install".freeze]
  s.files = ["exe/asciidoctor-pdf-cjk-kai_gen_gothic-install".freeze]
  s.homepage = "".freeze
  s.post_install_message = "\n======================\n\nRun this command to download required fonts:\n\n    $ asciidoctor-pdf-cjk-kai_gen_gothic-install\n\n======================\n\n".freeze
  s.rubygems_version = "3.1.3".freeze
  s.summary = "".freeze

  s.installed_by_version = "3.1.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<asciidoctor-pdf-cjk>.freeze, ["~> 0.1.2"])
    s.add_development_dependency(%q<bundler>.freeze, ["~> 1.10"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 10.0"])
    s.add_development_dependency(%q<minitest>.freeze, [">= 0"])
  else
    s.add_dependency(%q<asciidoctor-pdf-cjk>.freeze, ["~> 0.1.2"])
    s.add_dependency(%q<bundler>.freeze, ["~> 1.10"])
    s.add_dependency(%q<rake>.freeze, ["~> 10.0"])
    s.add_dependency(%q<minitest>.freeze, [">= 0"])
  end
end
