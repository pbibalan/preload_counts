# Inspired by https://github.com/smathieu/preload_counts (plus polymorphic types)
#
# This adds a scope to preload the counts of an association in one SQL query.
#
# Consider the following code:
# Matter.all.each{|m| puts m.contacts.count}
#
# Each time count is called, a db query is made to fetch the count.
#
# Adding this to the Matter class:
#
# preload_counts :contacts
#
# will add a preload_contact_counts scope to preload the counts and add
# accessors to the class. So our code becomes
#
# Matter.preload_contact_counts.all.each{|m| puts m.matters_count}
#
# And only requires one DB query.
module Clio
  module AR 
    module PreloadCounts
      module ClassMethods
        def preload_counts(association)
          name = "preload_#{association.to_s.singularize}_counts"
          singleton = class << self; self end
          scope_to_select(association)
          singleton.send :define_method, name do
            sql = ["#{table_name}.*",scope_to_select(association)]
            sql = sql.join(', ')
            all.select(sql)
          end
        end

        private
        def scope_to_select(association)
          reflections = self.reflections.with_indifferent_access[association]
          conditions = []
          r_scope = reflections.scope
          r_options = reflections.options
          binding.pry
          if r_scope
            conditions += self.instance_eval(&r_scope).where_values
          end

          foreign_key = r_options[:as].present? ? "#{r_options[:as]}_id" : "#{table_name.singularize}_id"

          sql = <<-SQL
          (SELECT count(*)
           FROM #{association}
           WHERE #{association}.#{foreign_key} = #{table_name}.id AND
           #{conditions_to_sql conditions}) AS #{find_accessor_name(association)}
          SQL
        end

        def find_accessor_name(association)
          "#{association}_count"
        end

        def conditions_to_sql(conditions)
          conditions = ["1 = 1"] if conditions.empty?
          conditions.join(" AND ")
        end
      end

      module InstanceMethods
      end

      def self.included(receiver)
        receiver.extend ClassMethods
        receiver.send :include, InstanceMethods
      end
    end
  end
end