module Proforma
  class Importer

    def from_proforma_xml(exercise, xml)
      @exercise = exercise
      doc = Nokogiri::XML(xml)
      doc.collect_namespaces

      @exercise.attributes = {
          title: doc.xpath('/p:task/p:meta-data/p:title').text,
          description: doc.xpath('/p:task/p:description').text
      }
      prog_language = doc.xpath('/p:task/p:proglang').text
      version = doc.xpath('/p:task/p:proglang/@version').first.value
      exec_environment = ExecutionEnvironment.where(name: prog_language + ' ' + version).take
      if exec_environment
        exec_environment_id = exec_environment.id
      else
        exec_environment_id = 1
      end
      @exercise.execution_environment_id = exec_environment_id

      add_files_xml(doc)

      return @exercise
    end

    def add_files_xml(xml)
      xml.xpath('/p:task/p:files/p:file').each do |file|
        role = determine_file_role_from_proforma_file(xml, file)
        filename_attribute = file.xpath('@filename').first
        file_id = file.xpath('@id').first.value
        file_class = file.xpath('@class').first.value
        content = file.text
        feedback_message = xml.xpath("//p:test/p:test-configuration/p:filerefs/p:fileref[@refid='#{file_id}']/../../c:feedback-message").text
        @exercise.files.build({
                        content: content,
                        name: get_filename_from_filename_attribute(filename_attribute),
                        path: get_path_from_filename_attribute(filename_attribute),
                        file_type: get_filetype_from_filename_attribute(filename_attribute),
                        role: role,
                        feedback_message: (role == 'teacher_defined_test') ? feedback_message : nil,
                        hidden: file_class == 'internal',
                        read_only: false })
      end
    end


    def split_up_filename(filename)
      if filename.include? '/'
        name_with_type = filename.split(/\/(?=[^\/]*$)/).second
        path = filename.split(/\/(?=[^\/]*$)/).first
      else
        name_with_type = filename
        path = ''
      end
      if name_with_type.include? '.'
        name  = name_with_type.split('.').first
        type = name_with_type.split('.').second
      else
        name = name_with_type
        type = ''
      end
      return path, name, type
    end

    def get_filetype_from_filename_attribute(filename_attribute)

      if filename_attribute
        type = split_up_filename(filename_attribute.value).third
        if type != ''
          return FileType.find_by(file_extension: ".#{type}")
        end
      end
      return FileType.find_by(name: 'Makefile')
    end

    def get_filename_from_filename_attribute(filename_attribute)

      if filename_attribute
        name = split_up_filename(filename_attribute.value).second
        return name
      else
        ''
      end
    end

    def get_path_from_filename_attribute(filename_attribute)

      if filename_attribute
        path = split_up_filename(filename_attribute.value).first
      end
      ''
    end

    def determine_file_role_from_proforma_file(xml, file)
      file_id = file.xpath('@id').first.value
      file_class = file.xpath('@class').first.value
      comment = file.xpath('@comment').first.try(:value)
      if teacher_defined_test?(xml, file_id, file_class)
        'teacher_defined_test'
      elsif reference_implementation?(xml, file_id, file_class)
        'reference_implementation'
      elsif (file_class == 'template') && (comment == 'main')
        'main_file'
      elsif (file_class == 'internal') && (comment == 'main')
        ''
      else
        'regular_file'
      end
    end

    def teacher_defined_test?(xml, file_id, file_class)
      is_referenced_by_test = xml.xpath("//p:test/p:test-configuration/p:filerefs/p:fileref[@refid='#{file_id}']")
      if is_referenced_by_test.any? && (file_class == 'internal')
        true
      else
        false
      end
    end

    def reference_implementation?(xml, file_id, file_class)
      is_referenced_by_model_solution = xml.xpath("//p:model-solution/p:filerefs/p:fileref[@refid='#{file_id}']")
      if is_referenced_by_model_solution.any? && (file_class == 'internal')
        true
      else
        false
      end
    end
  end
end