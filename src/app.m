classdef app < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                     matlab.ui.Figure
        ProfileIdDropDown            matlab.ui.control.DropDown
        ProfileIdDropDownLabel       matlab.ui.control.Label
        TestButton                   matlab.ui.control.Button
        TabGroup                     matlab.ui.container.TabGroup
        Tab                          matlab.ui.container.Tab
        DatabaseNameEditField        matlab.ui.control.EditField
        DatabaseNameEditFieldLabel   matlab.ui.control.Label
        DatabaseConnectionLamp       matlab.ui.control.Lamp
        DatabaseConnectionLampLabel  matlab.ui.control.Label
        PasswordEditField            matlab.ui.control.EditField
        PasswordEditFieldLabel       matlab.ui.control.Label
        UserEditField                matlab.ui.control.EditField
        UserEditFieldLabel           matlab.ui.control.Label
        ServerNameEditField          matlab.ui.control.EditField
        ServerNameEditFieldLabel     matlab.ui.control.Label
        ShowDataButton               matlab.ui.control.Button
        ConnectButton                matlab.ui.control.Button
        UIAxes_3                     matlab.ui.control.UIAxes
        UIAxes_2                     matlab.ui.control.UIAxes
        UIAxes                       matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        db % Database object
        dt_model % Pretrained Decision Tree model
        table_tabs % Cell array of Tabs in TabGroup
        tab_coeffs % Cell array of correlation coefficient matrixes for each tab
    end
    
    methods (Access = private)
        
        function results = db_exists(app)
            % Returns true if app.db is a database, otherwise false.
            results = class(app.db) == "Database";
        end

        function color = set_database_color(app, connected)
            if connected
                color = 'green';
            else
                color = 'red';
            end

            app.DatabaseConnectionLamp.Color = color;
        end

        function show_db_data (app)
            % plot data from the db to the table

            app.table_tabs = cell(1, length(app.db.tables));
            table_name = app.db.get_table_name(1);
            app.table_tabs{1} = app.Tab;
            app.table_tabs{1}.Title = table_name;
            app.table_tabs{1}.Scrollable = true;
            uitable(app.table_tabs{1}, 'Data', app.db.selectIn(table_name, {'*'}, {'id<=10'}));
            drawnow();

            for i=2:length(app.db.tables)
                table_name = app.db.get_table_name(i);
                app.table_tabs{i} = uitab(app.TabGroup, 'Title', table_name, 'Scrollable', true);
                uitable(app.table_tabs{i}, 'Data', app.db.selectIn(table_name, {'*'}, {'id<=10'}));
                drawnow();
            end
        end
        
        function calculate_coeffs(app)
            % get all the data from the database table
            % that each tab represents

            app.tab_coeffs = cell(1, length(app.table_tabs));

            for i=1:length(app.table_tabs)
                % get the database table name from the title of the tab
                table_name = app.table_tabs{i}.Title;
                
                % make select * query to get all the data
                data = app.db.selectIn(table_name, {'*'});
                data_types = varfun(@class, data, 'OutputFormat','cell');
                bad_data_columns = data.Properties.VariableNames(find(~strcmp(data_types, 'single')));
                data = removevars(data, bad_data_columns);
                % calculate correlation coefficients
                app.tab_coeffs{i} = corrcoef(table2array(data));
                clear data;
            end

            app.draw_correlation_matrix(app.table_tabs{1}.Title);
        end
        
        function draw_correlation_matrix(app, tab_name)
            
            tab_titles = cell(1, length(app.table_tabs));
            for i=1:length(tab_titles)
                tab_titles{i} = app.table_tabs{i}.Title;
            end

            tab_index = find(strcmp(tab_titles, tab_name));

            imagesc(app.UIAxes, app.tab_coeffs{tab_index});
            colormap(app.UIAxes, 'jet(4096)');
            colorbar(app.UIAxes);

            % set labels to match column names
            % get column names from an empty table
            tbl = app.db.selectIn(tab_name, {'*'}, 'id=0');
            tbl = removevars(tbl, {'id'});
            labels = tbl.Properties.VariableNames;

            label_interval = 1:1:13;
            xticks(app.UIAxes, label_interval);
            yticks(app.UIAxes, label_interval);
            xticklabels(app.UIAxes, labels);
            yticklabels(app.UIAxes, labels);
        end

        function set_temp_plot_options(app)
            % set options in Profile Id Drop down to profile ids of the
            % current tab

            currentTab = app.TabGroup.SelectedTab.Title;
            profile_ids = app.db.selectIn(currentTab, {'distinct profile_id'}).profile_id;
            profile_ids = transpose(string(sort(profile_ids)));

            app.ProfileIdDropDown.Items = profile_ids;
            app.ProfileIdDropDown.Value = profile_ids(1);

            app.draw_temp_plot();
        end

        function draw_temp_plot(app)
            % plot the temperatures of the selected profile id
            table_name = app.TabGroup.SelectedTab.Title;
            profile_id = app.ProfileIdDropDown.Value;

            if strcmp(profile_id, "")
               return;
            end
            
            condition = sprintf('profile_id=%s',string(profile_id));
            temp_data = app.db.selectIn(table_name, {'stator_winding', 'stator_tooth', 'stator_yoke', 'pm'}, condition);
            time = [1:length(temp_data.stator_winding)] / 2;
            cla(app.UIAxes_2);
            hold(app.UIAxes_2, 'on');
            plot(app.UIAxes_2, time, temp_data.stator_winding);
            plot(app.UIAxes_2, time, temp_data.stator_tooth);
            plot(app.UIAxes_2, time, temp_data.stator_yoke);
%             plot(app.UIAxes_2, 1:length(temp_data.stator_winding), temp_data.pm);
            hold(app.UIAxes_2, 'off');
            legend(app.UIAxes_2, 'stator\_winding', 'stator\_tooth', 'stator\_yoke');
            ylabel(app.UIAxes_2, 'Temperature (C^o)');
            xlabel(app.UIAxes_2, 'Time (s)');
        end

        function draw_pred_plot(app)
            profile_id = app.ProfileIdDropDown.Value;
            active_table = app.TabGroup.SelectedTab.Title;
    
            condition = sprintf('profile_id=%s', string(profile_id));
    
            true_data = app.db.selectIn(active_table, {'*'}, condition);
            true_vars = removevars(true_data, {'stator_winding', 'stator_tooth', 'pm', 'stator_yoke', 'torque', 'profile_id', 'id'});
            true_stator_mean = (true_data.stator_tooth + true_data.stator_winding + true_data.stator_yoke) ./ 3;
    
            prediction = smoothdata(predict(app.dt_model, true_vars), 'movmean');
    
            cla(app.UIAxes_3);
            time = [1:length(true_stator_mean)] / 2;
            hold(app.UIAxes_3, "on");
            plot(app.UIAxes_3, time, true_stator_mean);
            plot(app.UIAxes_3, time, prediction);
            hold(app.UIAxes_3, "off");
            legend(app.UIAxes_3, "True", "Prediction");
            ylabel(app.UIAxes_3, 'Temperature (C^o)');
            xlabel(app.UIAxes_3, 'Time (s)');
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            load('dt_model_v2.mat', 'mdl');
            app.dt_model = mdl;
        end

        % Button pushed function: ConnectButton
        function ConnectButtonPushed(app, event)
            
            % disconnect from the last database
            app.set_database_color(false);
            if app.db_exists
                app.db.disconnect();
            end
            clear app.db;
            
            % get input field values
            server_name = string(app.ServerNameEditField.Value);
            user_name = string(app.UserEditField.Value);
            pass = string(app.PasswordEditField.Value);
            db_name = string(app.DatabaseNameEditField.Value);
            
            try
                conn = connect(server_name, user_name, pass);
                app.db = Database(conn, db_name);
            catch e
                error(e.message);
                return;
            end

            app.set_database_color(true);
            app.show_db_data();
            drawnow();
            app.calculate_coeffs();
            app.set_temp_plot_options();
            app.draw_pred_plot();
        end

        % Button pushed function: ShowDataButton
        function ShowDataButtonPushed(app, event)
            if ~app.db_exists()
                error("Not connected to database");
            end

            disp(app.db.selectIn('test', {'*'}));
        end

        % Button pushed function: TestButton
        function TestButtonPushed(app, event)
              profile_id = app.ProfileIdDropDown.Value;
              active_table = app.TabGroup.SelectedTab.Title;

              condition = sprintf('profile_id=%s', string(profile_id));

              true_data = app.db.selectIn(active_table, {'*'}, condition);
              true_vars = removevars(true_data, {'stator_winding', 'stator_tooth', 'pm', 'stator_yoke', 'torque', 'profile_id', 'id'});
              true_stator_mean = (true_data.stator_tooth + true_data.stator_winding + true_data.stator_yoke) ./ 3;

              prediction = smoothdata(predict(app.dt_model, true_vars), 'movmean');

              cla(app.UIAxes_3);
              hold(app.UIAxes_3, "on");
              plot(app.UIAxes_3, true_stator_mean);
              plot(app.UIAxes_3, prediction);
              hold(app.UIAxes_3, "off");
              legend(app.UIAxes_3, "True", "Prediction");
        end

        % Selection change function: TabGroup
        function TabGroupSelectionChanged(app, event)
            selectedTab = app.TabGroup.SelectedTab;
            tab_name = selectedTab.Title;
            app.set_temp_plot_options();
            app.draw_correlation_matrix(tab_name);
            app.draw_pred_plot();
        end

        % Value changed function: ProfileIdDropDown
        function ProfileIdDropDownValueChanged(app, event)
            app.draw_temp_plot();
            app.draw_pred_plot();
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1000 480];
            app.UIFigure.Name = 'MATLAB App';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Correlation Matrix')
            app.UIAxes.Position = [314 128 357 254];

            % Create UIAxes_2
            app.UIAxes_2 = uiaxes(app.UIFigure);
            title(app.UIAxes_2, 'Profile id:')
            app.UIAxes_2.Position = [680 253 300 206];

            % Create UIAxes_3
            app.UIAxes_3 = uiaxes(app.UIFigure);
            title(app.UIAxes_3, 'Prediction using DT')
            app.UIAxes_3.Position = [670 48 300 206];

            % Create ConnectButton
            app.ConnectButton = uibutton(app.UIFigure, 'push');
            app.ConnectButton.ButtonPushedFcn = createCallbackFcn(app, @ConnectButtonPushed, true);
            app.ConnectButton.Position = [2 298 61 23];
            app.ConnectButton.Text = 'Connect';

            % Create ShowDataButton
            app.ShowDataButton = uibutton(app.UIFigure, 'push');
            app.ShowDataButton.ButtonPushedFcn = createCallbackFcn(app, @ShowDataButtonPushed, true);
            app.ShowDataButton.Visible = 'off';
            app.ShowDataButton.Position = [459 11 100 23];
            app.ShowDataButton.Text = 'Show Data';

            % Create ServerNameEditFieldLabel
            app.ServerNameEditFieldLabel = uilabel(app.UIFigure);
            app.ServerNameEditFieldLabel.HorizontalAlignment = 'right';
            app.ServerNameEditFieldLabel.Position = [1 423 75 22];
            app.ServerNameEditFieldLabel.Text = 'Server Name';

            % Create ServerNameEditField
            app.ServerNameEditField = uieditfield(app.UIFigure, 'text');
            app.ServerNameEditField.Position = [107 423 102 22];

            % Create UserEditFieldLabel
            app.UserEditFieldLabel = uilabel(app.UIFigure);
            app.UserEditFieldLabel.HorizontalAlignment = 'right';
            app.UserEditFieldLabel.Position = [2 391 30 22];
            app.UserEditFieldLabel.Text = 'User';

            % Create UserEditField
            app.UserEditField = uieditfield(app.UIFigure, 'text');
            app.UserEditField.Position = [107 391 101 22];

            % Create PasswordEditFieldLabel
            app.PasswordEditFieldLabel = uilabel(app.UIFigure);
            app.PasswordEditFieldLabel.HorizontalAlignment = 'right';
            app.PasswordEditFieldLabel.Position = [1 360 58 22];
            app.PasswordEditFieldLabel.Text = 'Password';

            % Create PasswordEditField
            app.PasswordEditField = uieditfield(app.UIFigure, 'text');
            app.PasswordEditField.Position = [107 360 101 22];

            % Create DatabaseConnectionLampLabel
            app.DatabaseConnectionLampLabel = uilabel(app.UIFigure);
            app.DatabaseConnectionLampLabel.HorizontalAlignment = 'right';
            app.DatabaseConnectionLampLabel.Position = [2 458 122 22];
            app.DatabaseConnectionLampLabel.Text = 'Database Connection';

            % Create DatabaseConnectionLamp
            app.DatabaseConnectionLamp = uilamp(app.UIFigure);
            app.DatabaseConnectionLamp.Position = [139 458 20 20];
            app.DatabaseConnectionLamp.Color = [1 0 0];

            % Create DatabaseNameEditFieldLabel
            app.DatabaseNameEditFieldLabel = uilabel(app.UIFigure);
            app.DatabaseNameEditFieldLabel.HorizontalAlignment = 'right';
            app.DatabaseNameEditFieldLabel.Position = [1 329 92 22];
            app.DatabaseNameEditFieldLabel.Text = 'Database Name';

            % Create DatabaseNameEditField
            app.DatabaseNameEditField = uieditfield(app.UIFigure, 'text');
            app.DatabaseNameEditField.Position = [108 329 101 22];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);
            app.TabGroup.Position = [5 11 310 280];

            % Create Tab
            app.Tab = uitab(app.TabGroup);
            app.Tab.Title = 'Tab';
            app.Tab.Scrollable = 'on';

            % Create TestButton
            app.TestButton = uibutton(app.UIFigure, 'push');
            app.TestButton.ButtonPushedFcn = createCallbackFcn(app, @TestButtonPushed, true);
            app.TestButton.Visible = 'off';
            app.TestButton.Position = [344 11 100 23];
            app.TestButton.Text = 'Test';

            % Create ProfileIdDropDownLabel
            app.ProfileIdDropDownLabel = uilabel(app.UIFigure);
            app.ProfileIdDropDownLabel.HorizontalAlignment = 'right';
            app.ProfileIdDropDownLabel.Position = [695 27 53 22];
            app.ProfileIdDropDownLabel.Text = 'Profile Id';

            % Create ProfileIdDropDown
            app.ProfileIdDropDown = uidropdown(app.UIFigure);
            app.ProfileIdDropDown.Items = {};
            app.ProfileIdDropDown.ValueChangedFcn = createCallbackFcn(app, @ProfileIdDropDownValueChanged, true);
            app.ProfileIdDropDown.Position = [763 27 50 22];
            app.ProfileIdDropDown.Value = {};

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = app

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
