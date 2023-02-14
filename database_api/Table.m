classdef Table
    %Table A class representing a table in a database
    
    properties
        db, name, columns
    end
    
    methods (Access=public)
        function obj = Table(db, table_name)
            arguments
                db Database
                table_name string
            end
            %Table Construct an instance of this class
            %   Construct a Table object that represents a table in the
            %   passed database.

            obj.name = table_name;
            obj.db = db;

            % get table columns
            query = sprintf('SELECT * FROM information_schema.columns WHERE table_name=''%s''', table_name);
            obj.columns = select(db.connection, query);
        end

        function [data, select_query] = select(obj, columns, conditions, useOr)
            arguments
                obj Table
                columns (1, :) string
                conditions (1, :) string = {''}
                useOr logical = true
            end
            % Returns data from specified columns in table based on a list
            % of optional conditions.
            %
            % @param columns cell array with column names
            % @param conditions cell array with all the conditions to select
            % data by e.g. {'id=1', 'name="John"', 'salary=1000 AND id < 10'}
            % @param useOr a logical value that indicates whether or not
            % the conditions should be combined using logical OR or AND.
            % If true then data returned satisfy conditions, otherwise the 
            % data returned satisfies at least one condition.

            columns_string = strjoin(columns, ', ');

            conditions_string = obj.join_conditions(conditions, useOr);
            if strlength(conditions_string) > 1
                conditions_string = strjoin(['WHERE', conditions_string], ' ');
            end

            select_query = sprintf('SELECT %s FROM %s', columns_string, obj.name{:});
            if strlength(conditions_string) > 1
                select_query = strjoin([select_query, conditions_string], ' ');
            end

            data = select(obj.db.connection, select_query);
        end

        function delete_query = delete(obj, conditions, useOr)
            arguments
                obj Table
                conditions (1, :) string = {''}
                useOr logical = true
            end
            % Deletes all rows in table that match the passed conditions.
            % If no conditions passed then all rows are deleted.

            conditions_string = obj.join_conditions(conditions, useOr);
            delete_query = sprintf('DELETE FROM %s', obj.name);
            if strlength(conditions_string)
                delete_query = sprintf('%s WHERE %s', delete_query, conditions_string);
            end

            execute(obj.db.connection, delete_query);
        end

        function inserted = insert(obj, columns, values)
            arguments
                obj Table
                columns (:, 1) string
                values (1, :, :) 
            end
            
            inserted = table;
            for i=1:1:length(columns)
                inserted.(columns{i}) = values{i};
            end

            sqlwrite(obj.db.connection, obj.name, inserted);
        end

        function update_query = update(obj, columns, values, conditions, useOr)
            arguments
                obj Table
                columns (1, :) string
                values (1, :)
                conditions (1, :) string = {''}
                useOr logical = true
            end
            % Updates table columns with the given values based on passed
            % conditions.

            if length(columns) ~= length(values)
                error('A set value must be provided for each column.');
            end

            % convert all values to string &
            % put strings inside single quotes
            for i=1:1:length(values)
                if ischar(values{i}) || isstring(values{i})
                    values{i} = "'" + values{i} + "'";
                else
                    values{i} = string(values{i});
                end
            end

            if length(columns) > 1
                columns_string = "(" + strjoin(columns, ', ') + ")";
                values_string = "(" + strjoin([values{:}], ', ') + ")";
            else
                columns_string = columns{1};
                values_string = string(values{1});
            end

            conditions_string = obj.join_conditions(conditions, useOr);

            update_query = sprintf('UPDATE %s SET %s=%s', obj.name, columns_string, values_string);

            if strlength(conditions_string) > 1
                update_query = sprintf('%s WHERE %s', update_query, conditions_string);
            end

            execute(obj.db.connection, update_query);
        end
    end

    methods (Access=private)
        function conditions_string = join_conditions(obj, conditions, useOr)
            arguments
                obj Table
                conditions (1, :) string
                useOr logical = true
            end
            % Parse a set of conditions into a single string

            if useOr
                logicalDelimeter = 'OR';
            else
                logicalDelimeter = 'AND';
            end

            delimeter = sprintf(' %s ', logicalDelimeter);
            conditions_string = strjoin(conditions, delimeter);
        end
    end

end

