USE [CARS24DataModelingSystem];
GO

IF OBJECT_ID(N'core.Branch', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[Branch]
    (
        [branch_id] INT IDENTITY(1,1) NOT NULL,
        [city_id] INT NOT NULL,
        [branch_code] VARCHAR(30) NOT NULL,
        [branch_name] NVARCHAR(150) NOT NULL,
        [address_text] NVARCHAR(500) NULL,
        [status] VARCHAR(20) NOT NULL,
        CONSTRAINT [PK_Branch] PRIMARY KEY ([branch_id]),
        CONSTRAINT [UQ_Branch_branch_code] UNIQUE ([branch_code]),
        CONSTRAINT [FK_Branch_City_city_id] FOREIGN KEY ([city_id]) REFERENCES [ref].[City] ([city_id]),
        CONSTRAINT [CK_Branch_status] CHECK ([status] IN ('ACTIVE', 'INACTIVE', 'CLOSED')),
        CONSTRAINT [CK_Branch_code_upper] CHECK ([branch_code] = UPPER([branch_code]))
    );
END;
GO

IF OBJECT_ID(N'core.Employee', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[Employee]
    (
        [employee_id] INT IDENTITY(1,1) NOT NULL,
        [branch_id] INT NOT NULL,
        [employee_code] VARCHAR(30) NOT NULL,
        [display_name] NVARCHAR(150) NOT NULL,
        [active_from] DATE NOT NULL,
        [active_to] DATE NULL,
        CONSTRAINT [PK_Employee] PRIMARY KEY ([employee_id]),
        CONSTRAINT [UQ_Employee_employee_code] UNIQUE ([employee_code]),
        CONSTRAINT [FK_Employee_Branch_branch_id] FOREIGN KEY ([branch_id]) REFERENCES [core].[Branch] ([branch_id]),
        CONSTRAINT [CK_Employee_active_dates] CHECK ([active_to] IS NULL OR [active_to] >= [active_from]),
        CONSTRAINT [CK_Employee_code_upper] CHECK ([employee_code] = UPPER([employee_code]))
    );
END;
GO

IF OBJECT_ID(N'core.EmployeeRole', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[EmployeeRole]
    (
        [employee_role_id] INT IDENTITY(1,1) NOT NULL,
        [employee_id] INT NOT NULL,
        [role_code] VARCHAR(30) NOT NULL,
        [valid_from] DATETIME2(0) NOT NULL,
        [valid_to] DATETIME2(0) NULL,
        CONSTRAINT [PK_EmployeeRole] PRIMARY KEY ([employee_role_id]),
        CONSTRAINT [FK_EmployeeRole_Employee_employee_id] FOREIGN KEY ([employee_id]) REFERENCES [core].[Employee] ([employee_id]),
        CONSTRAINT [UQ_EmployeeRole_employee_id_role_code_valid_from] UNIQUE ([employee_id], [role_code], [valid_from]),
        CONSTRAINT [CK_EmployeeRole_valid_dates] CHECK ([valid_to] IS NULL OR [valid_to] > [valid_from]),
        CONSTRAINT [CK_EmployeeRole_role_code_upper] CHECK ([role_code] = UPPER([role_code]))
    );
END;
GO

IF OBJECT_ID(N'core.Customer', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[Customer]
    (
        [customer_id] INT IDENTITY(1,1) NOT NULL,
        [display_name] NVARCHAR(150) NOT NULL,
        [legal_name] NVARCHAR(150) NULL,
        [status] VARCHAR(20) NOT NULL,
        [created_at] DATETIME2(0) NOT NULL
            CONSTRAINT [DF_Customer_created_at] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_Customer] PRIMARY KEY ([customer_id]),
        CONSTRAINT [CK_Customer_status] CHECK ([status] IN ('ACTIVE', 'INACTIVE', 'SUSPENDED'))
    );
END;
GO

IF OBJECT_ID(N'core.CustomerContact', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[CustomerContact]
    (
        [contact_id] INT IDENTITY(1,1) NOT NULL,
        [customer_id] INT NOT NULL,
        [contact_type] VARCHAR(10) NOT NULL,
        [contact_value] NVARCHAR(254) NOT NULL,
        [is_verified] BIT NOT NULL
            CONSTRAINT [DF_CustomerContact_is_verified] DEFAULT (0),
        [valid_from] DATETIME2(0) NOT NULL,
        [valid_to] DATETIME2(0) NULL,
        CONSTRAINT [PK_CustomerContact] PRIMARY KEY ([contact_id]),
        CONSTRAINT [FK_CustomerContact_Customer_customer_id] FOREIGN KEY ([customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [UQ_CustomerContact_customer_type_value_valid_from]
            UNIQUE ([customer_id], [contact_type], [contact_value], [valid_from]),
        CONSTRAINT [CK_CustomerContact_type] CHECK ([contact_type] IN ('EMAIL', 'PHONE', 'OTHER')),
        CONSTRAINT [CK_CustomerContact_valid_dates] CHECK ([valid_to] IS NULL OR [valid_to] > [valid_from])
    );
END;
GO

IF OBJECT_ID(N'core.CustomerAddress', N'U') IS NULL
BEGIN
    CREATE TABLE [core].[CustomerAddress]
    (
        [address_id] INT IDENTITY(1,1) NOT NULL,
        [customer_id] INT NOT NULL,
        [city_id] INT NOT NULL,
        [address_type] VARCHAR(20) NOT NULL,
        [address_line1] NVARCHAR(200) NOT NULL,
        [address_line2] NVARCHAR(200) NULL,
        [postal_code] VARCHAR(6) NOT NULL,
        [valid_from] DATETIME2(0) NOT NULL,
        [valid_to] DATETIME2(0) NULL,
        CONSTRAINT [PK_CustomerAddress] PRIMARY KEY ([address_id]),
        CONSTRAINT [FK_CustomerAddress_Customer_customer_id] FOREIGN KEY ([customer_id]) REFERENCES [core].[Customer] ([customer_id]),
        CONSTRAINT [FK_CustomerAddress_City_city_id] FOREIGN KEY ([city_id]) REFERENCES [ref].[City] ([city_id]),
        CONSTRAINT [CK_CustomerAddress_type] CHECK ([address_type] IN ('HOME', 'MAILING', 'DELIVERY', 'OTHER')),
        CONSTRAINT [CK_CustomerAddress_pin_code] CHECK ([postal_code] NOT LIKE '%[^0-9]%' AND LEN([postal_code]) = 6),
        CONSTRAINT [CK_CustomerAddress_valid_dates] CHECK ([valid_to] IS NULL OR [valid_to] > [valid_from])
    );
END;
GO
