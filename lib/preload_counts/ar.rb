# This adds a scope to preload the counts of an association in one SQL query.
#
# Consider the following code:
# Service.all.each{|s| puts s.incidents.acknowledged.count}
#
# Each time count is called, a db query is made to fetch the count.
#
# Adding this to the Service class:
#
# preload_counts :incidents => [:acknowledged]
#
# will add a preload_incident_counts scope to preload the counts and add
# accessors to the class. So our codes becaumes
#
# Service.preload_incident_counts.all.each{|s| puts s.acknowledged_incidents_count}
#
# And only requires one DB query.
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

      accessor_name = get_accessor_name(association)
      define_method  "#{association}_count" do
        result = public_send(association)
        (self[accessor_name] || result.size).to_i
      end
    end


    private
    def scope_to_select(association)
      association_reflections = self.reflections.with_indifferent_access[association]
      r_options = association_reflections.options
      throw ArgumentError.new "not implemented for through associations" if r_options[:through]
      r_as = r_options[:as]
      r_foreign_key = association_reflections.foreign_key || "#{table_name.singularize}_id"
      r_foreign_type = association_reflections.foreign_type
      r_class_name = association_reflections.class_name
      resolved_association = r_class_name.present? ? r_class_name.singularize.constantize : association.to_s.singularize.camelize.constantize
      conditions = []

      r_scope = association_reflections.scope
      if r_scope
        conditions += self.instance_eval(&r_scope).where_values
      end

      association_table_name = resolved_association.table_name
      
      association_condition = "#{association_table_name}.#{r_foreign_key} = #{table_name}.id"
      association_condition += " AND #{association_table_name}.#{r_as}_type = '#{name}'" if r_as

      sql = <<-SQL
      (SELECT count(*)
       FROM #{association_table_name}
       WHERE #{association_condition} AND 
       #{conditions_to_sql conditions}) AS #{get_accessor_name(association)}
      SQL
    end

    def get_accessor_name(association)
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

ActiveRecord::Base.class_eval { include PreloadCounts }

