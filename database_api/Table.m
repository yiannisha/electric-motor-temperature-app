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
                conditions (1, :) string
                useOr logical
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

            if ~exist("conditions", "var")
                conditions = "";
            end

            if ~exist("useOr", "var")
                useOr = true;
            end

            columns_string = strjoin(columns, ', ');

            if useOr
                logicalDelimeter = 'OR';
            else
                logicalDelimeter = 'AND';
            end

            conditions_string = strjoin(conditions, sprintf(' %s ', logicalDelimeter));
            if strlength(conditions_string) > 1
                conditions_string = strjoin(["WHERE", conditions_string], ' ');
            end

            sqlquery = sprintf('%s %s FROM %s', upper(action), columns_string, obj.name{:});
            if strlength(conditions_string) > 1
                sqlquery = strjoin([sqlquery, conditions_string], ' ');
            end

            data = select(obj.db.connection, sqlquery);
        end
    end
end

