-- PROJECT: Nashville Housing Data Engineering
-- PHASE 1: DATA CLEANING

-- 1. Standardize Date Format 
ALTER TABLE dbo.NashvilleHousing 
ADD SaleDateConverted DATE; 

UPDATE dbo.NashvilleHousing 
SET SaleDateConverted = CONVERT(Date, SaleDate);

-- 2. Populate Missing Property Address Data
UPDATE a 
SET PropertyAddress = ISNULL(a.PropertyAddress,b.PropertyAddress) 
FROM dbo.NashvilleHousing a 
JOIN dbo.NashvilleHousing b 
    ON a.ParcelID = b.ParcelID 
    AND a.[UniqueID ] <> b.[UniqueID ] 
WHERE a.PropertyAddress IS NULL; 

-- 3. Breaking out Property Address into Individual Columns (Address, City)
ALTER TABLE dbo.NashvilleHousing 
ADD PropertySplitAddress Nvarchar(255), 
    PropertySplitCity Nvarchar(255); 

UPDATE dbo.NashvilleHousing 
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1), 
    PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress)); 

-- 4. Breaking out Owner Address into Individual Columns (Address, City, State) 
ALTER TABLE dbo.NashvilleHousing 
ADD OwnerSplitAddress Nvarchar(255), 
    OwnerSplitCity Nvarchar(255), 
    OwnerSplitState Nvarchar(255);]

UPDATE dbo.NashvilleHousing 
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 3), 
    OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 2), 
    OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.') , 1); 

-- 5. Standardize "Sold as Vacant" (Change Y/N to YES/NO)
UPDATE dbo.NashvilleHousing]
SET SoldAsVacant = CASE 
    WHEN SoldAsVacant = 'Y' THEN 'YES'
    WHEN SoldAsVacant = 'N' THEN 'NO' 
    ELSE SoldAsVacant 
    END; 

-- 6. Remove Duplicates 
WITH RowNumCTE AS( 
    SELECT *, 
        ROW_NUMBER() OVER ( 
            PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference 
            ORDER BY UniqueID 
        ) AS row_num 
    FROM dbo.NashvilleHousing 
) 
DELETE 
FROM RowNumCTE 
WHERE row_num > 1; 

-- 7. Delete Unused Columns
ALTER TABLE dbo.NashvilleHousing 
DROP COLUMN OwnerAddress, TaxDistrict, PropertyAddress, SaleDate; 


-- PHASE 2: DATA WAREHOUSE (STAR SCHEMA)

-- 1. Create and Populate Dim_Property (The "What & Where")
CREATE TABLE dbo.Dim_Property ( 
    PropertyKey INT IDENTITY(1,1) PRIMARY KEY, 
    ParcelID NVARCHAR(50), 
    PropertyAddress NVARCHAR(255), 
    PropertyCity NVARCHAR(255), 
    YearBuilt INT, 
    Bedrooms INT, 
    FullBath INT, 
    HalfBath INT, 
    Acreage FLOAT 
); 

INSERT INTO dbo.Dim_Property (ParcelID, PropertyAddress, PropertyCity, YearBuilt, Bedrooms, FullBath, HalfBath, Acreage) 
SELECT DISTINCT 
    ParcelID, 
    PropertySplitAddress, 
    PropertySplitCity, 
    YearBuilt, 
    Bedrooms, 
    FullBath, 
    HalfBath, 
    Acreage 
FROM dbo.NashvilleHousing 
WHERE ParcelID IS NOT NULL; 

-- 2. Create and Populate Dim_Date (The "When") 
CREATE TABLE dbo.Dim_Date ( 
    DateKey INT PRIMARY KEY, 
    FullDate DATE, 
    SaleYear INT, 
    SaleMonth INT, 
    SaleQuarter INT 
); 

INSERT INTO dbo.Dim_Date (DateKey, FullDate, SaleYear, SaleMonth, SaleQuarter) 
SELECT DISTINCT 
    CAST(FORMAT(SaleDateConverted, 'yyyyMMdd') AS INT) AS DateKey, 
    SaleDateConverted, 
    YEAR(SaleDateConverted) AS SaleYear, 
    MONTH(SaleDateConverted) AS SaleMonth, 
    DATEPART(QUARTER, SaleDateConverted) AS SaleQuarter 
FROM dbo.NashvilleHousing 
WHERE SaleDateConverted IS NOT NULL; 

-- 3. Create and Populate Fact_Sales (The "How Much") 
CREATE TABLE dbo.Fact_Sales (
    SaleKey INT IDENTITY(1,1) PRIMARY KEY, 
    PropertyKey INT, 
    DateKey INT, 
    UniqueID NVARCHAR(50), 
    SalePrice NUMERIC(15,2), 
    SoldAsVacant VARCHAR(3), 
    LegalReference NVARCHAR(255) 
); 

INSERT INTO dbo.Fact_Sales (PropertyKey, DateKey, UniqueID, SalePrice, SoldAsVacant, LegalReference) 
SELECT 
    p.PropertyKey, 
    CAST(FORMAT(raw.SaleDateConverted, 'yyyyMMdd') AS INT) AS DateKey, 
    raw.UniqueID, 
    raw.SalePrice, 
    raw.SoldAsVacant, 
    raw.LegalReference 
FROM dbo.NashvilleHousing raw 
JOIN dbo.Dim_Property p 
    ON raw.ParcelID = p.ParcelID; 

-- 4. Verify Your Data Warehouse 
SELECT TOP 10 
    f.SalePrice, 
    d.SaleYear, 
    p.PropertyCity, 
    p.Bedrooms 
FROM dbo.Fact_Sales f 
JOIN dbo.Dim_Property p ON f.PropertyKey = p.PropertyKey 
JOIN dbo.Dim_Date d ON f.DateKey = d.DateKey;
