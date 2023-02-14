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

        function data = select(obj, columns, conditions, useOr)
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

            if useOr
                logicalDelimeter = 'OR';
            else
                logicalDelimeter = 'AND';
            end

            conditions_string = obj.join_conditions(conditions, logicalDelimeter);
            if strlength(conditions_string) > 1
                conditions_string = strjoin(['WHERE', conditions_string], ' ');
            end

            sqlquery = sprintf('SELECT %s FROM %s', columns_string, obj.name{:});
            if strlength(conditions_string) > 1
                sqlquery = strjoin([sqlquery, conditions_string], ' ');
            end

            data = select(obj.db.connection, sqlquery);
        end

        function deleted = delete(obj, conditions, useOr)
            arguments
                obj Table
                conditions (1, :) string = {''}
                useOr logical = true
            end
            % Deletes all rows in table that match the passed conditions.
            % If no conditions passed then all rows are deleted.
            
            if useOr
                logicalDelimeter = 'OR';
            else
                logicalDelimeter = 'AND';
            end

            conditions_string = obj.join_conditions(conditions, logicalDelimeter);
            query = sprintf('DELETE FROM %s', obj.name);
            if strlength(conditions_string)
                query = sprintf('%s WHERE %s', query, conditions_string);
            end

            execute(obj.db.connection, query);
            deleted = true;
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
    end

    methods (Access=private)
        function conditions_string = join_conditions(obj, conditions, logicalDelimeter)
            arguments
                obj Table
                conditions (1, :) string
                logicalDelimeter string
            end
            % Parse a set of conditions into a single string
            delimeter = sprintf(' %s ', logicalDelimeter);
            conditions_string = strjoin(conditions, delimeter);
        end
    end

end

