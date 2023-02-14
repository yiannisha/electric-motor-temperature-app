classdef Database
    %DATABASE A class representing a database.
    
    properties
        connection, db_name, tablesMap, tables
    end
    
    methods (Access=public)
        function obj = Database(connection, db_name)
            %DATABASE Construct an instance of this class
            %   Construct a Database object that represents a database on
            %   the passed connection object
            
            obj.connection = connection;
            obj.db_name = db_name;

            % verify that the db named `db_name` exists
            if isempty(find(strcmp(connection.catalogs, db_name), 1))
                error('Database %s not found in server.', db_name);
            end

            % get created tables that belong to the database
            
            % get table names
            sqlquery = sprintf(string(['SELECT tablename FROM pg_catalog.pg_tables ' ...
                'WHERE tableowner=''%s''']), obj.db_name);
            table_names = select(obj.connection, sqlquery).tablename;

            % create a Table object for each table
            obj.tables = Table.empty(length(table_names), 0);
            for i=1:1:length(table_names)
                obj.tables(i) = Table(obj, table_names{i});
            end

            obj.tablesMap = containers.Map(table_names, 1:1:length(obj.tables));
        end

        function [data, select_query] = selectIn(obj, table_name, columns, conditions, useOr)
            arguments
                obj Database
                table_name string
                columns (1, :) string
                conditions (1, :) string = {''}
                useOr logical = true
            end
            % Returns data from specified columns in table based on a list
            % of optional conditions.
            %
            % @param columns cell array with column names
            % 
            % @param conditions cell array with all the conditions to select
            % data by e.g. {'id=1', 'name="John"', 'salary=1000 AND id < 10'}
            %
            % @param useOr a logical value that indicates whether or not
            % the conditions should be combined using logical OR or AND.
            % If true then data returned satisfy conditions, otherwise the 
            % data returned satisfies at least one condition.
            %
            % @param table_name name of the table to query

            table = obj.getTable(table_name);
            [data, select_query] = table.select(columns, conditions, useOr);
        end

        function inserted = insertIn(obj, table_name, columns, values)
            arguments
                obj Database
                table_name string
                columns (:, 1) string
                values (1, :, :)
            end

            table = obj.getTable(table_name);
            inserted = table.insert(columns, values);
        end

        function delete_query = deleteIn(obj, table_name, conditions, useOr)
            arguments
                obj Database
                table_name string
                conditions (1, :) string = {''}
                useOr logical = true
            end
            
            table = obj.getTable(table_name);
            delete_query = table.delete(conditions, useOr);
        end

        function update_query = updateIn(obj, table_name, columns, values, conditions, useOr)
            arguments
                obj Database
                table_name string
                columns (1, :) string
                values (1, :)
                conditions (1, :) string = {''}
                useOr logical = true
            end

            table = obj.getTable(table_name);
            update_query = table.update(columns, values, conditions, useOr);
        end
    end
   
    methods (Access=private)
        function table = getTable(obj, table_name)
            arguments
                obj Database
                table_name string
            end
           % Returns the table with the specified name if it exists in the
           % database.
           %
           % @param table_name string with the table's name

            table = obj.tables(obj.tablesMap(table_name));
        end
    end
end

