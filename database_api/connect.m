function connection = connect(serverName, username, password)
%CONNECT Returns a connection object if it successfully connects to a
%database.
connection = database(serverName, username, password);
end

