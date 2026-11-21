/* Day 3 Phase 01. Inserts deterministic staff/customer rows only.
   Requires Day 2 schemas/tables and existing Day 2 branches. */
USE [CARS24DataModelingSystem];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'CARS24DataModelingSystem' THROW 51000, 'Wrong database. Phase 01 stopped.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @lockResult int;
    EXEC @lockResult=sys.sp_getapplock @Resource=N'CARS24-Day3-Generation',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=0,@DbPrincipal=N'public';
    IF @lockResult<0 THROW 51009, 'Could not obtain exclusive Day 3 generation lock.', 1;
IF (SELECT COUNT_BIG(*) FROM sys.schemas WHERE name IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery'))<>10
 OR (SELECT COUNT_BIG(*) FROM sys.tables WHERE schema_id IN (SELECT schema_id FROM sys.schemas WHERE name IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery')))<>34
 OR (SELECT COUNT_BIG(*) FROM sys.key_constraints k JOIN sys.tables t ON t.object_id=k.parent_object_id WHERE k.type='PK' AND SCHEMA_NAME(t.schema_id) IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery'))<>34
 OR (SELECT COUNT_BIG(*) FROM sys.foreign_keys f JOIN sys.tables t ON t.object_id=f.parent_object_id WHERE SCHEMA_NAME(t.schema_id) IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery'))<>62
 OR (SELECT COUNT_BIG(*) FROM sys.key_constraints k JOIN sys.tables t ON t.object_id=k.parent_object_id WHERE k.type='UQ' AND SCHEMA_NAME(t.schema_id) IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery'))<>19
 OR (SELECT COUNT_BIG(*) FROM sys.check_constraints c JOIN sys.tables t ON t.object_id=c.parent_object_id WHERE SCHEMA_NAME(t.schema_id) IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery'))<>79
 OR (SELECT COUNT_BIG(*) FROM sys.default_constraints d JOIN sys.tables t ON t.object_id=d.parent_object_id WHERE SCHEMA_NAME(t.schema_id) IN (N'ref',N'core',N'vehicle',N'inspection',N'acquisition',N'inventory',N'marketplace',N'sales',N'finance',N'delivery'))<>8
 OR EXISTS (SELECT 1 FROM sys.foreign_keys WHERE is_disabled=1 OR is_not_trusted=1)
 OR EXISTS (SELECT 1 FROM sys.check_constraints WHERE is_disabled=1 OR is_not_trusted=1)
 OR EXISTS (SELECT 1 FROM sys.indexes WHERE index_id>0 AND is_disabled=1)
    THROW 51990,'Day 2 schema or constraint prerequisites failed. No generation phase may continue.',1;
IF OBJECT_ID(N'core.Branch',N'U') IS NULL OR OBJECT_ID(N'core.Employee',N'U') IS NULL OR OBJECT_ID(N'core.Customer',N'U') IS NULL
    THROW 51001, 'Required Day 2 tables are missing. Phase 01 stopped.', 1;
IF NOT EXISTS (SELECT 1 FROM core.Branch WHERE branch_code='HYD-CEN') OR NOT EXISTS (SELECT 1 FROM core.Branch WHERE branch_code='MUM-WST')
    THROW 51002, 'Expected Day 2 branch keys are missing. Phase 01 stopped.', 1;
IF (SELECT COUNT_BIG(*) FROM core.Branch WHERE branch_code IN ('HYD-CEN','MUM-WST','BLR-SOU','PUN-CEN','DEL-SOU','CHE-CEN','AMD-CEN','RJK-CEN'))<>8
    THROW 51018, 'The eight planned Day 2 branch keys must resolve exactly once. Phase 01 stopped.', 1;
IF (SELECT COUNT_BIG(*) FROM ref.City WHERE country_code='IN' AND city_name IN (N'Hyderabad',N'Mumbai',N'Bengaluru',N'Pune',N'Delhi',N'Chennai',N'Ahmedabad',N'Rajkot'))<>8
    THROW 51019, 'The eight planned Day 2 city keys must resolve exactly once. Phase 01 stopped.', 1;
IF (SELECT COUNT_BIG(*) FROM core.Employee) <> 4 + (SELECT COUNT_BIG(*) FROM core.Employee WHERE employee_code LIKE 'D3-EMP-%')
    THROW 51013, 'Unclassified employee rows exist beyond the Day 2 baseline and Day 3 namespace. Reconcile before Phase 01.', 1;
IF (SELECT COUNT_BIG(*) FROM core.Customer) <> 3 + (SELECT COUNT_BIG(*) FROM core.Customer WHERE display_name LIKE N'D3 Synthetic Customer %')
    THROW 51014, 'Unclassified customer rows exist beyond the Day 2 baseline and Day 3 namespace. Reconcile before Phase 01.', 1;

DECLARE @Employees TABLE
(
    employee_code varchar(30) PRIMARY KEY, branch_code varchar(30) NOT NULL,
    display_name nvarchar(150) NOT NULL, role_code varchar(30) NOT NULL,
    active_from date NOT NULL, role_from datetime2(0) NOT NULL
);
;WITH n AS
(
    SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<21
)
INSERT INTO @Employees
SELECT CONCAT('D3-EMP-',RIGHT(CONCAT('0000',n),4)),
       CASE (n-1)%8 WHEN 0 THEN 'HYD-CEN' WHEN 1 THEN 'MUM-WST' WHEN 2 THEN 'BLR-SOU' WHEN 3 THEN 'PUN-CEN'
                    WHEN 4 THEN 'DEL-SOU' WHEN 5 THEN 'CHE-CEN' WHEN 6 THEN 'AMD-CEN' ELSE 'RJK-CEN' END,
       CONCAT(N'Day 3 Synthetic Employee ',RIGHT(CONCAT(N'0000',n),4)),
       CASE (n-1)%4 WHEN 0 THEN 'INSPECTOR' WHEN 1 THEN 'SALES_EXECUTIVE' WHEN 2 THEN 'INVENTORY_MANAGER' ELSE 'BRANCH_MANAGER' END,
       CONVERT(date,'20260201',112),CONVERT(datetime2(0),'2026-02-01T00:00:00')
FROM n OPTION (MAXRECURSION 100);

DECLARE @Customers TABLE
(
    customer_key int PRIMARY KEY, display_name nvarchar(150) NOT NULL,
    legal_name nvarchar(150) NULL, status varchar(20) NOT NULL,
    created_at datetime2(0) NOT NULL
);
;WITH n AS
(
    SELECT 1 AS n UNION ALL SELECT n+1 FROM n WHERE n<97
)
INSERT INTO @Customers
SELECT n,CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',n),4)),
       CONCAT(N'D3 Synthetic Customer ',RIGHT(CONCAT(N'0000',n),4)),
       CASE WHEN n%19=0 THEN 'INACTIVE' WHEN n%37=0 THEN 'SUSPENDED' ELSE 'ACTIVE' END,
       DATEADD(second,n,CONVERT(datetime2(0),'2026-02-01T10:00:00'))
FROM n OPTION (MAXRECURSION 100);

DECLARE @Contacts TABLE
(
    display_name nvarchar(150) NOT NULL, contact_type varchar(10) NOT NULL,
    contact_value nvarchar(254) NOT NULL, valid_from datetime2(0) NOT NULL,
    PRIMARY KEY(display_name,contact_type,valid_from)
);
INSERT INTO @Contacts
SELECT c.display_name,'EMAIL',CONCAT(N'day3.customer.',RIGHT(CONCAT(N'0000',c.customer_key),4),N'@example.invalid'),c.created_at FROM @Customers c
UNION ALL
SELECT c.display_name,'PHONE',CONCAT(N'+91-00000-',RIGHT(CONCAT(N'00000',c.customer_key),5)),c.created_at FROM @Customers c WHERE c.customer_key<=75;

DECLARE @Addresses TABLE
(
    display_name nvarchar(150) NOT NULL, address_line1 nvarchar(200) NOT NULL,
    city_name nvarchar(100) NOT NULL, postal_code varchar(6) NOT NULL,
    valid_from datetime2(0) NOT NULL, address_type varchar(20) NOT NULL,
    PRIMARY KEY(display_name,address_line1)
);
INSERT INTO @Addresses
SELECT c.display_name,CONCAT(N'D3 Synthetic Address ',RIGHT(CONCAT(N'0000',c.customer_key),4)),
       CASE (c.customer_key-1)%8 WHEN 0 THEN N'Hyderabad' WHEN 1 THEN N'Mumbai' WHEN 2 THEN N'Bengaluru' WHEN 3 THEN N'Pune'
            WHEN 4 THEN N'Delhi' WHEN 5 THEN N'Chennai' WHEN 6 THEN N'Ahmedabad' ELSE N'Rajkot' END,
       RIGHT(CONCAT('100000',100000+c.customer_key),6),c.created_at,'HOME'
FROM @Customers c
UNION ALL
SELECT c.display_name,CONCAT(N'D3 Synthetic Mailing Address ',RIGHT(CONCAT(N'0000',c.customer_key),4)),
       CASE (c.customer_key)%8 WHEN 0 THEN N'Hyderabad' WHEN 1 THEN N'Mumbai' WHEN 2 THEN N'Bengaluru' WHEN 3 THEN N'Pune'
            WHEN 4 THEN N'Delhi' WHEN 5 THEN N'Chennai' WHEN 6 THEN N'Ahmedabad' ELSE N'Rajkot' END,
       RIGHT(CONCAT('100000',200000+c.customer_key),6),DATEADD(day,30,c.created_at),'MAILING'
FROM @Customers c WHERE c.customer_key<=25;

/* Conflicts are not treated as successful skips: every natural-key match must
   resolve once and match the entire intended payload. */
IF EXISTS
(
    SELECT e.employee_code FROM @Employees e JOIN core.Employee x ON x.employee_code=e.employee_code
    LEFT JOIN core.Branch b ON b.branch_id=x.branch_id
    WHERE b.branch_code<>e.branch_code OR x.display_name<>e.display_name OR x.active_from<>e.active_from OR x.active_to IS NOT NULL
) THROW 51003, 'Employee natural-key payload conflict. Phase 01 stopped without writing.', 1;
IF EXISTS (SELECT e.employee_code FROM @Employees e JOIN core.Employee x ON x.employee_code=e.employee_code GROUP BY e.employee_code HAVING COUNT_BIG(*)>1)
    THROW 51004, 'Ambiguous employee natural key. Phase 01 stopped.', 1;
IF EXISTS
(
    SELECT e.employee_code FROM @Employees e JOIN core.Employee x ON x.employee_code=e.employee_code
    JOIN core.EmployeeRole r ON r.employee_id=x.employee_id AND r.role_code=e.role_code AND r.valid_from=e.role_from
    WHERE r.valid_to IS NOT NULL
) THROW 51015, 'Employee-role natural-key payload conflict. Phase 01 stopped without writing.', 1;
IF EXISTS
(
    SELECT c.display_name FROM @Customers c JOIN core.Customer x ON x.display_name=c.display_name
    WHERE ISNULL(x.legal_name,N'')<>ISNULL(c.legal_name,N'') OR x.status<>c.status OR x.created_at<>c.created_at
) THROW 51005, 'Customer natural-key payload conflict. Phase 01 stopped without writing.', 1;
IF EXISTS (SELECT c.display_name FROM @Customers c JOIN core.Customer x ON x.display_name=c.display_name GROUP BY c.display_name HAVING COUNT_BIG(*)>1)
    THROW 51006, 'Ambiguous customer natural key. Phase 01 stopped.', 1;
IF EXISTS
(
    SELECT cc.display_name,cc.contact_type,cc.contact_value,cc.valid_from
    FROM @Contacts cc JOIN core.Customer c ON c.display_name=cc.display_name
    JOIN core.CustomerContact x ON x.customer_id=c.customer_id AND x.contact_type=cc.contact_type AND x.contact_value=cc.contact_value AND x.valid_from=cc.valid_from
    WHERE x.is_verified<>0 OR x.valid_to IS NOT NULL
) THROW 51007, 'Contact natural-key payload conflict. Phase 01 stopped without writing.', 1;
IF EXISTS
(
    SELECT a.display_name,a.address_line1 FROM @Addresses a JOIN core.Customer c ON c.display_name=a.display_name
    JOIN core.CustomerAddress x ON x.customer_id=c.customer_id AND x.address_line1=a.address_line1
    WHERE x.address_type<>a.address_type OR x.postal_code<>a.postal_code OR x.valid_from<>a.valid_from OR x.valid_to IS NOT NULL
) THROW 51008, 'Address natural-key payload conflict. Phase 01 stopped without writing.', 1;

    /* The package lock and transaction were acquired before mutable prechecks. */
    DECLARE @employeeInserted int=0,@roleInserted int=0,@customerInserted int=0,@contactInserted int=0,@addressInserted int=0;
    INSERT INTO core.Employee(branch_id,employee_code,display_name,active_from)
    SELECT b.branch_id,e.employee_code,e.display_name,e.active_from
    FROM @Employees e JOIN core.Branch b ON b.branch_code=e.branch_code
    WHERE NOT EXISTS(SELECT 1 FROM core.Employee x WITH(UPDLOCK,HOLDLOCK) WHERE x.employee_code=e.employee_code);
    SET @employeeInserted=@@ROWCOUNT;

    INSERT INTO core.EmployeeRole(employee_id,role_code,valid_from)
    SELECT e.employee_id,s.role_code,s.role_from
    FROM @Employees s JOIN core.Employee e ON e.employee_code=s.employee_code
    WHERE NOT EXISTS(SELECT 1 FROM core.EmployeeRole r WITH(UPDLOCK,HOLDLOCK) WHERE r.employee_id=e.employee_id AND r.role_code=s.role_code AND r.valid_from=s.role_from);
    SET @roleInserted=@@ROWCOUNT;

    INSERT INTO core.Customer(display_name,legal_name,status,created_at)
    SELECT c.display_name,c.legal_name,c.status,c.created_at FROM @Customers c
    WHERE NOT EXISTS(SELECT 1 FROM core.Customer x WITH(UPDLOCK,HOLDLOCK) WHERE x.display_name=c.display_name);
    SET @customerInserted=@@ROWCOUNT;

    INSERT INTO core.CustomerContact(customer_id,contact_type,contact_value,is_verified,valid_from)
    SELECT c.customer_id,x.contact_type,x.contact_value,0,x.valid_from
    FROM @Contacts x JOIN core.Customer c ON c.display_name=x.display_name
    WHERE NOT EXISTS(SELECT 1 FROM core.CustomerContact z WITH(UPDLOCK,HOLDLOCK)
                     WHERE z.customer_id=c.customer_id AND z.contact_type=x.contact_type AND z.contact_value=x.contact_value AND z.valid_from=x.valid_from);
    SET @contactInserted=@@ROWCOUNT;

    INSERT INTO core.CustomerAddress(customer_id,city_id,address_type,address_line1,address_line2,postal_code,valid_from)
    SELECT c.customer_id,city.city_id,a.address_type,a.address_line1,NULL,a.postal_code,a.valid_from
    FROM @Addresses a JOIN core.Customer c ON c.display_name=a.display_name
    JOIN ref.City city ON city.city_name=a.city_name AND city.state_code=CASE a.city_name WHEN N'Hyderabad' THEN 'TG' WHEN N'Mumbai' THEN 'MH' WHEN N'Bengaluru' THEN 'KA' WHEN N'Pune' THEN 'MH' WHEN N'Delhi' THEN 'DL' WHEN N'Chennai' THEN 'TN' WHEN N'Ahmedabad' THEN 'GJ' ELSE 'GJ' END AND city.country_code='IN'
    WHERE NOT EXISTS(SELECT 1 FROM core.CustomerAddress z WITH(UPDLOCK,HOLDLOCK) WHERE z.customer_id=c.customer_id AND z.address_line1=a.address_line1);
    SET @addressInserted=@@ROWCOUNT;

    IF EXISTS(SELECT 1 FROM @Customers c JOIN core.Customer x ON x.display_name=c.display_name GROUP BY c.display_name HAVING COUNT_BIG(*)<>1)
        THROW 51010, 'Post-insert customer key validation failed.', 1;
    IF EXISTS(SELECT 1 FROM @Employees e JOIN core.Employee x ON x.employee_code=e.employee_code GROUP BY e.employee_code HAVING COUNT_BIG(*)<>1)
        THROW 51011, 'Post-insert employee key validation failed.', 1;
    IF EXISTS(SELECT 1 FROM @Employees e JOIN core.Employee x ON x.employee_code=e.employee_code WHERE NOT EXISTS(SELECT 1 FROM core.EmployeeRole r WHERE r.employee_id=x.employee_id AND r.role_code=e.role_code AND r.valid_from=e.role_from AND r.valid_to IS NULL))
        THROW 51016, 'Post-insert employee-role validation failed.', 1;
    IF EXISTS(SELECT 1 FROM @Customers c JOIN core.Customer x ON x.display_name=c.display_name WHERE NOT EXISTS(SELECT 1 FROM core.CustomerContact cc WHERE cc.customer_id=x.customer_id AND cc.valid_from=c.created_at))
        THROW 51012, 'Post-insert customer contact validation failed.', 1;
    IF EXISTS(SELECT 1 FROM @Contacts expected JOIN core.Customer c ON c.display_name=expected.display_name LEFT JOIN core.CustomerContact x ON x.customer_id=c.customer_id AND x.contact_type=expected.contact_type AND x.contact_value=expected.contact_value AND x.valid_from=expected.valid_from GROUP BY expected.display_name,expected.contact_type,expected.valid_from HAVING COUNT_BIG(x.contact_id)<>1)
        THROW 51020, 'Post-insert exact contact-key validation failed.', 1;
    IF EXISTS(SELECT 1 FROM @Addresses a JOIN core.Customer c ON c.display_name=a.display_name LEFT JOIN core.CustomerAddress x ON x.customer_id=c.customer_id AND x.address_line1=a.address_line1 GROUP BY a.display_name,a.address_line1 HAVING COUNT_BIG(x.address_id)<>1)
        THROW 51017, 'Post-insert customer-address validation failed.', 1;
    IF EXISTS(SELECT 1 FROM @Addresses a JOIN core.Customer c ON c.display_name=a.display_name JOIN ref.City city ON city.city_name=a.city_name AND city.country_code='IN' JOIN core.CustomerAddress x ON x.customer_id=c.customer_id AND x.address_line1=a.address_line1 WHERE x.city_id<>city.city_id OR x.address_type<>a.address_type OR x.address_line2 IS NOT NULL OR x.postal_code<>a.postal_code OR x.valid_from<>a.valid_from OR x.valid_to IS NOT NULL)
        THROW 51021, 'Post-insert complete address payload validation failed.', 1;

    COMMIT TRANSACTION;
    SELECT N'01 Customers and staff' AS phase_name,DB_NAME() AS target_database,N'COMMITTED' AS status,
           21 AS expected_employee_keys,@employeeInserted AS employees_inserted,21-@employeeInserted AS employees_exact_match_skipped,
           21 AS expected_role_keys,@roleInserted AS roles_inserted,21-@roleInserted AS roles_exact_match_skipped,
           97 AS expected_customer_keys,@customerInserted AS customers_inserted,97-@customerInserted AS customers_exact_match_skipped,
           172 AS expected_contact_keys,@contactInserted AS contacts_inserted,172-@contactInserted AS contacts_exact_match_skipped,
           122 AS expected_address_keys,@addressInserted AS addresses_inserted,122-@addressInserted AS addresses_exact_match_skipped,
           N'PASS' AS validation_result,N'Phase 02 permitted after reviewing counts and zero conflicts.' AS next_phase;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    SELECT N'01 Customers and staff' AS phase_name,DB_NAME() AS target_database,N'ROLLED_BACK' AS status,
           ERROR_NUMBER() AS error_number,ERROR_MESSAGE() AS error_detail,N'No subsequent phase is permitted.' AS next_phase;
    THROW;
END CATCH;
GO
