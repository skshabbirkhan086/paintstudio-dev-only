# Application services
`PngValidator.cs` validates the uploaded PNG before the API writes it to SQL Server.
`Program.cs` uses a `SqlConnectionStringBuilder` for RDS credentials so generated
password characters cannot break SQL Server connection-string parsing.
