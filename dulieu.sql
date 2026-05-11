-- ============================================================
-- HỆ THỐNG QUẢN LÝ TIỆM CẦM ĐỒ
-- pawnshop.sql - Cấu trúc + Dữ liệu mẫu
-- Chuẩn: SQL Server (T-SQL)
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'PawnShopDB')
    DROP DATABASE PawnShopDB;
GO

CREATE DATABASE PawnShopDB
    COLLATE Vietnamese_CI_AS;
GO

USE PawnShopDB;
GO

-- ============================================================
-- PHẦN 1: TẠO BẢNG (3NF)
-- ============================================================

-- 1. Bảng Khách Hàng
CREATE TABLE KhachHang (
    MaKH        INT IDENTITY(1,1) PRIMARY KEY,
    HoTen       NVARCHAR(100)   NOT NULL,
    CCCD        VARCHAR(12)     NOT NULL UNIQUE,
    DienThoai   VARCHAR(15)     NOT NULL,
    DiaChi      NVARCHAR(255)   NULL,
    NgaySinh    DATE            NULL,
    GhiChu      NVARCHAR(500)   NULL,
    NgayTao     DATETIME        NOT NULL DEFAULT GETDATE()
);

-- 2. Bảng Nhân Viên
CREATE TABLE NhanVien (
    MaNV        INT IDENTITY(1,1) PRIMARY KEY,
    HoTen       NVARCHAR(100)   NOT NULL,
    ChucVu      NVARCHAR(50)    NOT NULL DEFAULT N'Nhân viên',
    DienThoai   VARCHAR(15)     NULL,
    NgayVao     DATE            NOT NULL DEFAULT GETDATE()
);

-- 3. Bảng Danh Mục Tài Sản (loại tài sản)
CREATE TABLE DanhMucTS (
    MaDM        INT IDENTITY(1,1) PRIMARY KEY,
    TenDM       NVARCHAR(100)   NOT NULL,
    MoTa        NVARCHAR(255)   NULL
);

-- 4. Bảng Hợp Đồng
CREATE TABLE HopDong (
    MaHD        INT IDENTITY(1,1) PRIMARY KEY,
    MaKH        INT             NOT NULL,
    MaNV        INT             NOT NULL,           -- NV tiếp nhận
    SoTienVay   DECIMAL(18,2)   NOT NULL,
    LaiSuatNgay DECIMAL(10,6)   NOT NULL DEFAULT 0.005,  -- 0.5% = 5000đ/1tr/ngày
    NgayVay     DATE            NOT NULL DEFAULT GETDATE(),
    Deadline1   DATE            NOT NULL,           -- Hạn lãi đơn
    Deadline2   DATE            NOT NULL,           -- Hạn thanh lý
    TrangThai   NVARCHAR(50)    NOT NULL DEFAULT N'Đang vay'
                                CHECK (TrangThai IN (
                                    N'Đang vay',
                                    N'Quá hạn',
                                    N'Đã thanh toán',
                                    N'Đã thanh lý'
                                )),
    GhiChu      NVARCHAR(500)   NULL,
    NgayTao     DATETIME        NOT NULL DEFAULT GETDATE(),
    NgayCapNhat DATETIME        NULL,

    CONSTRAINT FK_HD_KH FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH),
    CONSTRAINT FK_HD_NV FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV),
    CONSTRAINT CHK_HD_Deadline CHECK (Deadline2 > Deadline1 AND Deadline1 > NgayVay),
    CONSTRAINT CHK_HD_SoTien   CHECK (SoTienVay > 0)
);

-- 5. Bảng Tài Sản Thế Chấp
CREATE TABLE TaiSan (
    MaTS        INT IDENTITY(1,1) PRIMARY KEY,
    MaHD        INT             NOT NULL,
    MaDM        INT             NOT NULL,
    TenTS       NVARCHAR(200)   NOT NULL,
    MoTa        NVARCHAR(500)   NULL,
    GiaTriDinhGia DECIMAL(18,2) NOT NULL,           -- Giá trị định giá khi cầm
    TrangThai   NVARCHAR(50)    NOT NULL DEFAULT N'Đang giữ'
                                CHECK (TrangThai IN (
                                    N'Đang giữ',
                                    N'Đã trả',
                                    N'Đã thanh lý'
                                )),
    NgayNhap    DATETIME        NOT NULL DEFAULT GETDATE(),
    NgayCapNhat DATETIME        NULL,

    CONSTRAINT FK_TS_HD FOREIGN KEY (MaHD) REFERENCES HopDong(MaHD),
    CONSTRAINT FK_TS_DM FOREIGN KEY (MaDM) REFERENCES DanhMucTS(MaDM),
    CONSTRAINT CHK_TS_GiaTri CHECK (GiaTriDinhGia > 0)
);

-- 6. Bảng Giao Dịch Trả Nợ
CREATE TABLE GiaoDich (
    MaGD        INT IDENTITY(1,1) PRIMARY KEY,
    MaHD        INT             NOT NULL,
    MaNV        INT             NOT NULL,           -- NV thu tiền
    NgayGD      DATETIME        NOT NULL DEFAULT GETDATE(),
    LoaiGD      NVARCHAR(50)    NOT NULL
                                CHECK (LoaiGD IN (
                                    N'Trả nợ',
                                    N'Trả lãi gia hạn',
                                    N'Thanh lý'
                                )),
    SoTienThu   DECIMAL(18,2)   NOT NULL,
    DuNoTruoc   DECIMAL(18,2)   NOT NULL,           -- Dư nợ trước giao dịch
    DuNoSau     DECIMAL(18,2)   NOT NULL,           -- Dư nợ sau giao dịch
    GhiChu      NVARCHAR(500)   NULL,

    CONSTRAINT FK_GD_HD FOREIGN KEY (MaHD) REFERENCES HopDong(MaHD),
    CONSTRAINT FK_GD_NV FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV),
    CONSTRAINT CHK_GD_SoTien CHECK (SoTienThu > 0)
);

-- 7. Bảng Log Trạng Thái (Audit)
CREATE TABLE LogTrangThai (
    MaLog       INT IDENTITY(1,1) PRIMARY KEY,
    LoaiDoiTuong NVARCHAR(20)  NOT NULL CHECK (LoaiDoiTuong IN (N'HopDong', N'TaiSan')),
    MaDoiTuong  INT             NOT NULL,
    TrangThaiCu NVARCHAR(50)   NULL,
    TrangThaiMoi NVARCHAR(50)  NOT NULL,
    LyDo        NVARCHAR(255)  NULL,
    NguoiThucHien NVARCHAR(100) NULL,
    ThoiGian    DATETIME       NOT NULL DEFAULT GETDATE()
);

-- 8. Bảng Gia Hạn
CREATE TABLE GiaHan (
    MaGH        INT IDENTITY(1,1) PRIMARY KEY,
    MaHD        INT             NOT NULL,
    MaGD        INT             NOT NULL,           -- Giao dịch trả lãi gia hạn
    DeadlineCu  DATE            NOT NULL,
    DeadlineMoi DATE            NOT NULL,
    TienLaiDaTraDenHan DECIMAL(18,2) NOT NULL,      -- Lãi tích lũy đến ngày gia hạn
    NgayGiaHan  DATETIME        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_GH_HD FOREIGN KEY (MaHD) REFERENCES HopDong(MaHD),
    CONSTRAINT FK_GH_GD FOREIGN KEY (MaGD) REFERENCES GiaoDich(MaGD)
);


-- ============================================================
-- PHẦN 2: VIEWS HỖ TRỢ
-- ============================================================

-- View tổng hợp hợp đồng hiện tại
CREATE VIEW vw_HopDongTongHop AS
SELECT
    hd.MaHD,
    kh.HoTen        AS TenKhachHang,
    kh.CCCD,
    kh.DienThoai,
    hd.SoTienVay,
    hd.LaiSuatNgay,
    hd.NgayVay,
    hd.Deadline1,
    hd.Deadline2,
    hd.TrangThai,
    DATEDIFF(DAY, hd.NgayVay, CAST(GETDATE() AS DATE)) AS SoNgayVay,
    ISNULL((SELECT SUM(gd.SoTienThu) FROM GiaoDich gd WHERE gd.MaHD = hd.MaHD), 0) AS TongDaTra,
    (SELECT COUNT(*) FROM TaiSan ts WHERE ts.MaHD = hd.MaHD AND ts.TrangThai = N'Đang giữ') AS SoTSConLai,
    (SELECT SUM(ts.GiaTriDinhGia) FROM TaiSan ts WHERE ts.MaHD = hd.MaHD AND ts.TrangThai = N'Đang giữ') AS TongGiaTriTSConLai
FROM HopDong hd
JOIN KhachHang kh ON kh.MaKH = hd.MaKH;
GO


-- ============================================================
-- PHẦN 3: FUNCTIONS
-- ============================================================

-- fn_CalcLaiDon: Tính lãi đơn tích lũy đến một ngày
CREATE FUNCTION fn_CalcLaiDon (
    @MaHD       INT,
    @NgayTinh   DATE
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @SoTienGoc  DECIMAL(18,2);
    DECLARE @LaiSuat    DECIMAL(10,6);
    DECLARE @NgayVay    DATE;
    DECLARE @Deadline1  DATE;
    DECLARE @NgayKetThucLaiDon DATE;
    DECLARE @SoNgay     INT;
    DECLARE @LaiDon     DECIMAL(18,2);

    SELECT  @SoTienGoc  = SoTienVay,
            @LaiSuat    = LaiSuatNgay,
            @NgayVay    = NgayVay,
            @Deadline1  = Deadline1
    FROM HopDong WHERE MaHD = @MaHD;

    -- Lãi đơn tính từ NgayVay đến min(@NgayTinh, Deadline1)
    SET @NgayKetThucLaiDon = CASE WHEN @NgayTinh <= @Deadline1 THEN @NgayTinh ELSE @Deadline1 END;
    SET @SoNgay = DATEDIFF(DAY, @NgayVay, @NgayKetThucLaiDon);
    IF @SoNgay < 0 SET @SoNgay = 0;

    SET @LaiDon = @SoTienGoc * @LaiSuat * @SoNgay;
    RETURN @LaiDon;
END;
GO

-- fn_CalcMoneyContract: Tính tổng nợ (Gốc + Lãi đơn + Lãi kép) đến ngày chỉ định
CREATE FUNCTION fn_CalcMoneyContract (
    @MaHD       INT,
    @NgayTinh   DATE
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @SoTienGoc      DECIMAL(18,2);
    DECLARE @LaiSuat        DECIMAL(10,6);
    DECLARE @NgayVay        DATE;
    DECLARE @Deadline1      DATE;
    DECLARE @LaiDonDenD1    DECIMAL(18,2);
    DECLARE @GocPlusLaiDon  DECIMAL(18,2);  -- Gốc + Lãi đơn (cơ sở lãi kép)
    DECLARE @SoNgayKep      INT;
    DECLARE @TongNo         DECIMAL(18,2);

    SELECT  @SoTienGoc  = SoTienVay,
            @LaiSuat    = LaiSuatNgay,
            @NgayVay    = NgayVay,
            @Deadline1  = Deadline1
    FROM HopDong WHERE MaHD = @MaHD;

    -- Lãi đơn đến Deadline1
    SET @LaiDonDenD1 = @SoTienGoc * @LaiSuat * DATEDIFF(DAY, @NgayVay, @Deadline1);

    IF @NgayTinh <= @Deadline1
    BEGIN
        -- Còn trong giai đoạn lãi đơn
        DECLARE @SoNgayDon INT = DATEDIFF(DAY, @NgayVay, @NgayTinh);
        SET @TongNo = @SoTienGoc + (@SoTienGoc * @LaiSuat * @SoNgayDon);
    END
    ELSE
    BEGIN
        -- Qua Deadline1: lãi kép trên (Gốc + Lãi đơn đến D1)
        SET @GocPlusLaiDon = @SoTienGoc + @LaiDonDenD1;
        SET @SoNgayKep = DATEDIFF(DAY, @Deadline1, @NgayTinh);
        -- Lãi kép: A*(1+r)^n
        SET @TongNo = @GocPlusLaiDon * POWER(CAST(1 + @LaiSuat AS FLOAT), @SoNgayKep);
    END;

    RETURN ROUND(@TongNo, 0);
END;
GO

-- fn_CalcMoneyTransaction: Tính số tiền còn phải trả sau khi trừ đã thanh toán
CREATE FUNCTION fn_CalcMoneyTransaction (
    @MaHD       INT,
    @NgayTinh   DATE
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @TongNo     DECIMAL(18,2);
    DECLARE @DaTra      DECIMAL(18,2);
    DECLARE @ConLai     DECIMAL(18,2);

    SET @TongNo = dbo.fn_CalcMoneyContract(@MaHD, @NgayTinh);
    SELECT @DaTra = ISNULL(SUM(SoTienThu), 0)
    FROM GiaoDich
    WHERE MaHD = @MaHD AND LoaiGD IN (N'Trả nợ', N'Thanh lý');

    SET @ConLai = @TongNo - @DaTra;
    IF @ConLai < 0 SET @ConLai = 0;
    RETURN @ConLai;
END;
GO


-- ============================================================
-- PHẦN 4: STORED PROCEDURES
-- ============================================================

-- SP1: Tiếp nhận hợp đồng mới
CREATE PROCEDURE sp_TiepNhanHopDong
    @MaKH           INT,
    @MaNV           INT,
    @SoTienVay      DECIMAL(18,2),
    @SoNgayLaiDon   INT,            -- Số ngày lãi đơn (= Deadline1 - NgayVay)
    @SoNgayThanhLy  INT,            -- Thêm bao nhiêu ngày từ D1 đến D2
    -- Tài sản (tối đa 5 tài sản, truyền NULL nếu không có)
    @MaDM1 INT = NULL, @TenTS1 NVARCHAR(200) = NULL, @GiaTri1 DECIMAL(18,2) = NULL, @MoTa1 NVARCHAR(500) = NULL,
    @MaDM2 INT = NULL, @TenTS2 NVARCHAR(200) = NULL, @GiaTri2 DECIMAL(18,2) = NULL, @MoTa2 NVARCHAR(500) = NULL,
    @MaDM3 INT = NULL, @TenTS3 NVARCHAR(200) = NULL, @GiaTri3 DECIMAL(18,2) = NULL, @MoTa3 NVARCHAR(500) = NULL,
    @MaDM4 INT = NULL, @TenTS4 NVARCHAR(200) = NULL, @GiaTri4 DECIMAL(18,2) = NULL, @MoTa4 NVARCHAR(500) = NULL,
    @MaDM5 INT = NULL, @TenTS5 NVARCHAR(200) = NULL, @GiaTri5 DECIMAL(18,2) = NULL, @MoTa5 NVARCHAR(500) = NULL,
    @GhiChu         NVARCHAR(500) = NULL,
    @MaHD_Output    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Kiểm tra khách hàng tồn tại
        IF NOT EXISTS (SELECT 1 FROM KhachHang WHERE MaKH = @MaKH)
            THROW 50001, N'Khách hàng không tồn tại.', 1;

        IF @SoTienVay <= 0
            THROW 50002, N'Số tiền vay phải > 0.', 1;

        DECLARE @NgayVay  DATE = CAST(GETDATE() AS DATE);
        DECLARE @D1       DATE = DATEADD(DAY, @SoNgayLaiDon, @NgayVay);
        DECLARE @D2       DATE = DATEADD(DAY, @SoNgayThanhLy, @D1);

        -- Tạo hợp đồng
        INSERT INTO HopDong (MaKH, MaNV, SoTienVay, NgayVay, Deadline1, Deadline2, GhiChu)
        VALUES (@MaKH, @MaNV, @SoTienVay, @NgayVay, @D1, @D2, @GhiChu);

        SET @MaHD_Output = SCOPE_IDENTITY();

        -- Thêm tài sản
        IF @TenTS1 IS NOT NULL
            INSERT INTO TaiSan (MaHD, MaDM, TenTS, GiaTriDinhGia, MoTa) VALUES (@MaHD_Output, @MaDM1, @TenTS1, @GiaTri1, @MoTa1);
        IF @TenTS2 IS NOT NULL
            INSERT INTO TaiSan (MaHD, MaDM, TenTS, GiaTriDinhGia, MoTa) VALUES (@MaHD_Output, @MaDM2, @TenTS2, @GiaTri2, @MoTa2);
        IF @TenTS3 IS NOT NULL
            INSERT INTO TaiSan (MaHD, MaDM, TenTS, GiaTriDinhGia, MoTa) VALUES (@MaHD_Output, @MaDM3, @TenTS3, @GiaTri3, @MoTa3);
        IF @TenTS4 IS NOT NULL
            INSERT INTO TaiSan (MaHD, MaDM, TenTS, GiaTriDinhGia, MoTa) VALUES (@MaHD_Output, @MaDM4, @TenTS4, @GiaTri4, @MoTa4);
        IF @TenTS5 IS NOT NULL
            INSERT INTO TaiSan (MaHD, MaDM, TenTS, GiaTriDinhGia, MoTa) VALUES (@MaHD_Output, @MaDM5, @TenTS5, @GiaTri5, @MoTa5);

        -- Kiểm tra tổng giá trị tài sản >= tiền vay
        DECLARE @TongGiaTri DECIMAL(18,2);
        SELECT @TongGiaTri = SUM(GiaTriDinhGia) FROM TaiSan WHERE MaHD = @MaHD_Output;
        IF @TongGiaTri < @SoTienVay
            THROW 50003, N'Tổng giá trị tài sản thế chấp phải >= số tiền vay.', 1;

        -- Log
        INSERT INTO LogTrangThai (LoaiDoiTuong, MaDoiTuong, TrangThaiCu, TrangThaiMoi, LyDo)
        VALUES (N'HopDong', @MaHD_Output, NULL, N'Đang vay', N'Tạo hợp đồng mới');

        COMMIT;
        SELECT @MaHD_Output AS MaHopDong,
               @NgayVay AS NgayVay,
               @D1 AS Deadline1,
               @D2 AS Deadline2,
               N'Tạo hợp đồng thành công' AS ThongBao;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- SP2: Xử lý trả nợ
CREATE PROCEDURE sp_TraNo
    @MaHD       INT,
    @MaNV       INT,
    @SoTienThu  DECIMAL(18,2),
    @LoaiGD     NVARCHAR(50) = N'Trả nợ',
    @GhiChu     NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @NgayHom_Nay DATE = CAST(GETDATE() AS DATE);

        -- Kiểm tra hợp đồng hợp lệ
        IF NOT EXISTS (SELECT 1 FROM HopDong WHERE MaHD = @MaHD AND TrangThai NOT IN (N'Đã thanh toán', N'Đã thanh lý'))
            THROW 50010, N'Hợp đồng không tồn tại hoặc đã kết thúc.', 1;

        -- Tính dư nợ hiện tại
        DECLARE @DuNoHienTai DECIMAL(18,2) = dbo.fn_CalcMoneyTransaction(@MaHD, @NgayHom_Nay);

        IF @SoTienThu > @DuNoHienTai
            THROW 50011, N'Số tiền thu vượt quá dư nợ.', 1;

        DECLARE @DuNoSau DECIMAL(18,2) = @DuNoHienTai - @SoTienThu;

        -- Ghi giao dịch
        INSERT INTO GiaoDich (MaHD, MaNV, LoaiGD, SoTienThu, DuNoTruoc, DuNoSau, GhiChu)
        VALUES (@MaHD, @MaNV, @LoaiGD, @SoTienThu, @DuNoHienTai, @DuNoSau, @GhiChu);

        -- Cập nhật trạng thái hợp đồng
        DECLARE @TrangThaiMoi NVARCHAR(50);
        IF @DuNoSau = 0
        BEGIN
            SET @TrangThaiMoi = N'Đã thanh toán';
            -- Trả lại tất cả tài sản còn giữ
            UPDATE TaiSan SET TrangThai = N'Đã trả', NgayCapNhat = GETDATE()
            WHERE MaHD = @MaHD AND TrangThai = N'Đang giữ';
        END
        ELSE
            SET @TrangThaiMoi = (SELECT TrangThai FROM HopDong WHERE MaHD = @MaHD); -- Giữ nguyên

        UPDATE HopDong SET TrangThai = @TrangThaiMoi, NgayCapNhat = GETDATE()
        WHERE MaHD = @MaHD;

        -- Log
        DECLARE @TrangThaiCu NVARCHAR(50);
        SELECT @TrangThaiCu = TrangThai FROM HopDong WHERE MaHD = @MaHD;
        INSERT INTO LogTrangThai (LoaiDoiTuong, MaDoiTuong, TrangThaiCu, TrangThaiMoi, LyDo)
        VALUES (N'HopDong', @MaHD, @TrangThaiCu, @TrangThaiMoi, N'Trả nợ - số tiền: ' + CAST(@SoTienThu AS NVARCHAR));

        -- Gợi ý tài sản có thể trả lại (nếu còn nợ)
        IF @DuNoSau > 0
        BEGIN
            SELECT
                ts.MaTS, ts.TenTS, ts.GiaTriDinhGia,
                N'Có thể trả lại' AS GoiY,
                @DuNoSau AS DuNoSauGD
            FROM TaiSan ts
            WHERE ts.MaHD = @MaHD AND ts.TrangThai = N'Đang giữ'
              AND (
                -- Nếu trả tài sản này, tổng còn lại vẫn >= dư nợ
                (SELECT SUM(GiaTriDinhGia) FROM TaiSan WHERE MaHD = @MaHD AND TrangThai = N'Đang giữ')
                - ts.GiaTriDinhGia >= @DuNoSau
              );
        END

        COMMIT;
        SELECT
            @DuNoHienTai AS DuNoTruocGD,
            @SoTienThu   AS SoTienDaThu,
            @DuNoSau     AS DuNoSauGD,
            @TrangThaiMoi AS TrangThaiHopDong,
            CASE WHEN @DuNoSau = 0 THEN N'Đã thanh toán đủ' ELSE N'Đang trả góp' END AS TinhTrang;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- SP3: Gia hạn hợp đồng (trả lãi để dời Deadline1)
CREATE PROCEDURE sp_GiaHan
    @MaHD           INT,
    @MaNV           INT,
    @SoNgayGiaHan   INT             -- Số ngày gia hạn thêm
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @NgayHom_Nay DATE = CAST(GETDATE() AS DATE);

        DECLARE @Deadline1 DATE, @Deadline2 DATE, @TrangThai NVARCHAR(50);
        SELECT @Deadline1 = Deadline1, @Deadline2 = Deadline2, @TrangThai = TrangThai
        FROM HopDong WHERE MaHD = @MaHD;

        IF @TrangThai IN (N'Đã thanh toán', N'Đã thanh lý')
            THROW 50020, N'Hợp đồng đã kết thúc, không thể gia hạn.', 1;

        IF @NgayHom_Nay > @Deadline1
            THROW 50021, N'Đã quá Deadline1, không thể gia hạn - áp dụng lãi kép.', 1;

        -- Tính lãi đơn đến hiện tại
        DECLARE @LaiDonHienTai DECIMAL(18,2) = dbo.fn_CalcLaiDon(@MaHD, @NgayHom_Nay);

        -- Thu lãi gia hạn
        DECLARE @MaGD_New INT;
        INSERT INTO GiaoDich (MaHD, MaNV, LoaiGD, SoTienThu, DuNoTruoc, DuNoSau, GhiChu)
        VALUES (@MaHD, @MaNV, N'Trả lãi gia hạn', @LaiDonHienTai,
                dbo.fn_CalcMoneyTransaction(@MaHD, @NgayHom_Nay),
                dbo.fn_CalcMoneyTransaction(@MaHD, @NgayHom_Nay) - @LaiDonHienTai,
                N'Gia hạn ' + CAST(@SoNgayGiaHan AS NVARCHAR) + N' ngày');

        SET @MaGD_New = SCOPE_IDENTITY();

        -- Cập nhật deadline mới
        DECLARE @D1_Moi DATE = DATEADD(DAY, @SoNgayGiaHan, @Deadline1);
        DECLARE @D2_Moi DATE = DATEADD(DAY, @SoNgayGiaHan, @Deadline2);

        INSERT INTO GiaHan (MaHD, MaGD, DeadlineCu, DeadlineMoi, TienLaiDaTraDenHan)
        VALUES (@MaHD, @MaGD_New, @Deadline1, @D1_Moi, @LaiDonHienTai);

        UPDATE HopDong SET Deadline1 = @D1_Moi, Deadline2 = @D2_Moi, NgayCapNhat = GETDATE()
        WHERE MaHD = @MaHD;

        INSERT INTO LogTrangThai (LoaiDoiTuong, MaDoiTuong, TrangThaiCu, TrangThaiMoi, LyDo)
        VALUES (N'HopDong', @MaHD, @TrangThai, @TrangThai,
                N'Gia hạn từ ' + CONVERT(NVARCHAR, @Deadline1, 103) + N' → ' + CONVERT(NVARCHAR, @D1_Moi, 103));

        COMMIT;
        SELECT @D1_Moi AS Deadline1_Moi, @D2_Moi AS Deadline2_Moi,
               @LaiDonHienTai AS TienLaiDaTraDeGiaHan,
               N'Gia hạn thành công' AS ThongBao;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- SP4: Trả lại tài sản cụ thể
CREATE PROCEDURE sp_TraTaiSan
    @MaTS   INT,
    @MaNV   INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @MaHD INT, @GiaTriTS DECIMAL(18,2);
        SELECT @MaHD = MaHD, @GiaTriTS = GiaTriDinhGia FROM TaiSan WHERE MaTS = @MaTS;

        IF @MaHD IS NULL THROW 50030, N'Tài sản không tồn tại.', 1;

        DECLARE @DuNo DECIMAL(18,2) = dbo.fn_CalcMoneyTransaction(@MaHD, CAST(GETDATE() AS DATE));

        -- Tổng GT tài sản còn lại nếu trả tài sản này
        DECLARE @TongConLai DECIMAL(18,2);
        SELECT @TongConLai = SUM(GiaTriDinhGia) - @GiaTriTS
        FROM TaiSan WHERE MaHD = @MaHD AND TrangThai = N'Đang giữ';

        IF @TongConLai < @DuNo
            THROW 50031, N'Không thể trả tài sản: tổng giá trị còn lại sẽ < dư nợ hiện tại.', 1;

        UPDATE TaiSan SET TrangThai = N'Đã trả', NgayCapNhat = GETDATE() WHERE MaTS = @MaTS;

        INSERT INTO LogTrangThai (LoaiDoiTuong, MaDoiTuong, TrangThaiCu, TrangThaiMoi, LyDo)
        VALUES (N'TaiSan', @MaTS, N'Đang giữ', N'Đã trả', N'Trả lại tài sản cho khách');

        COMMIT;
        SELECT N'Trả tài sản thành công' AS ThongBao, @TongConLai AS TongGiaTriTSConLai, @DuNo AS DuNoHienTai;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH;
END;
GO


-- ============================================================
-- PHẦN 5: TRIGGERS
-- ============================================================

-- Trigger: Tự động cập nhật trạng thái hợp đồng Quá hạn (chạy qua job/manual)
-- Trong SQL Server thực tế nên dùng SQL Agent Job, nhưng đây là trigger mẫu
-- Trigger này bắt trên INSERT của GiaoDich để re-check trạng thái

CREATE TRIGGER trg_GiaoDich_AfterInsert
ON GiaoDich
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    -- Không có logic thêm ở đây vì SP đã xử lý trạng thái
    -- Trigger này dùng để đảm bảo tính toàn vẹn
END;
GO

-- Trigger: Khi cập nhật TaiSan về Đã thanh lý, kiểm tra toàn bộ HD
CREATE TRIGGER trg_TaiSan_AfterUpdate
ON TaiSan
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Nếu tất cả tài sản của HD đều thanh lý -> chuyển HD sang Đã thanh lý
    UPDATE hd
    SET hd.TrangThai = N'Đã thanh lý', hd.NgayCapNhat = GETDATE()
    FROM HopDong hd
    JOIN inserted i ON i.MaHD = hd.MaHD
    WHERE hd.TrangThai NOT IN (N'Đã thanh toán', N'Đã thanh lý')
      AND NOT EXISTS (
          SELECT 1 FROM TaiSan ts
          WHERE ts.MaHD = hd.MaHD AND ts.TrangThai = N'Đang giữ'
      );
END;
GO


-- ============================================================
-- PHẦN 6: TRUY VẤN NỢ XẤU (Báo cáo)
-- ============================================================

-- View báo cáo nợ xấu (quá Deadline1)
CREATE VIEW vw_NoxauBaoCao AS
SELECT
    hd.MaHD,
    kh.HoTen           AS TenKhachHang,
    kh.CCCD,
    kh.DienThoai,
    hd.SoTienVay       AS TienGoc,
    hd.NgayVay,
    hd.Deadline1,
    hd.Deadline2,
    DATEDIFF(DAY, hd.Deadline1, CAST(GETDATE() AS DATE)) AS SoNgayQuaHan,
    dbo.fn_CalcMoneyContract(hd.MaHD, CAST(GETDATE() AS DATE)) AS TongNoHienTai,
    dbo.fn_CalcMoneyTransaction(hd.MaHD, CAST(GETDATE() AS DATE)) AS DuNoHienTai,
    dbo.fn_CalcMoneyTransaction(hd.MaHD, DATEADD(MONTH, 1, CAST(GETDATE() AS DATE))) AS DuNoDuBao1Thang,
    (SELECT SUM(GiaTriDinhGia) FROM TaiSan WHERE MaHD = hd.MaHD AND TrangThai = N'Đang giữ') AS TongGiaTriTSConLai,
    hd.TrangThai
FROM HopDong hd
JOIN KhachHang kh ON kh.MaKH = hd.MaKH
WHERE CAST(GETDATE() AS DATE) > hd.Deadline1
  AND hd.TrangThai NOT IN (N'Đã thanh toán', N'Đã thanh lý');
GO


-- Stored Procedure cập nhật trạng thái nợ xấu (chạy định kỳ hàng ngày)
CREATE PROCEDURE sp_CapNhatTrangThaiHangNgay
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Hom_Nay DATE = CAST(GETDATE() AS DATE);

    -- Chuyển sang Quá hạn nếu qua Deadline1
    UPDATE HopDong
    SET TrangThai = N'Quá hạn', NgayCapNhat = GETDATE()
    WHERE TrangThai = N'Đang vay'
      AND @Hom_Nay > Deadline1;

    -- Log các HD vừa chuyển
    INSERT INTO LogTrangThai (LoaiDoiTuong, MaDoiTuong, TrangThaiCu, TrangThaiMoi, LyDo, NguoiThucHien)
    SELECT N'HopDong', MaHD, N'Đang vay', N'Quá hạn',
           N'Tự động: Quá Deadline1 ' + CONVERT(NVARCHAR, Deadline1, 103),
           N'System'
    FROM HopDong
    WHERE TrangThai = N'Quá hạn'
      AND NgayCapNhat >= DATEADD(MINUTE, -5, GETDATE()); -- Vừa cập nhật

    -- Thanh lý tự động khi qua Deadline2 (tùy chính sách tiệm)
    -- UPDATE HopDong SET TrangThai = N'Đã thanh lý' WHERE TrangThai = N'Quá hạn' AND @Hom_Nay > Deadline2;
END;
GO


-- ============================================================
-- PHẦN 7: DỮ LIỆU MẪU
-- ============================================================

-- Nhân viên
INSERT INTO NhanVien (HoTen, ChucVu, DienThoai) VALUES
(N'Nguyễn Văn Toàn', N'Quản lý', '0912345678'),
(N'Trần Thị Bình', N'Nhân viên', '0987654321'),
(N'Lê Minh Phúc', N'Nhân viên', '0901234567');

-- Danh mục tài sản
INSERT INTO DanhMucTS (TenDM, MoTa) VALUES
(N'Điện thoại', N'Smartphone, điện thoại thông thường'),
(N'Laptop/Máy tính', N'Laptop, máy tính xách tay'),
(N'Trang sức', N'Vàng, bạc, đá quý'),
(N'Xe máy', N'Xe máy, xe đạp điện'),
(N'Đồng hồ', N'Đồng hồ cao cấp'),
(N'Thiết bị điện tử', N'Camera, máy ảnh, TV...');

-- Khách hàng
INSERT INTO KhachHang (HoTen, CCCD, DienThoai, DiaChi, NgaySinh) VALUES
(N'Phạm Văn An', '034012345678', '0901111111', N'123 Lý Thái Tổ, Thái Nguyên', '1990-05-15'),
(N'Nguyễn Thị Bé', '046023456789', '0902222222', N'456 Hoàng Văn Thụ, Thái Nguyên', '1985-08-20'),
(N'Trần Văn Cường', '037034567890', '0903333333', N'789 Phan Đình Phùng, Thái Nguyên', '1995-12-01'),
(N'Lê Thị Dung', '027045678901', '0904444444', N'321 Bắc Kạn, Thái Nguyên', '1988-03-25'),
(N'Hoàng Văn Em', '038056789012', '0905555555', N'654 Cách Mạng Tháng 8, Thái Nguyên', '1978-07-10');

-- Hợp đồng mẫu (tạo thủ công để kiểm soát ngày)
-- HD1: Đang trong hạn lãi đơn
INSERT INTO HopDong (MaKH, MaNV, SoTienVay, NgayVay, Deadline1, Deadline2, GhiChu)
VALUES (1, 2, 5000000, '2025-04-20', '2025-05-20', '2025-06-20', N'Hợp đồng thông thường 30 ngày');

-- HD2: Đã qua Deadline1 (nợ xấu)
INSERT INTO HopDong (MaKH, MaNV, SoTienVay, NgayVay, Deadline1, Deadline2, TrangThai)
VALUES (2, 2, 10000000, '2025-03-01', '2025-04-01', '2025-05-01', N'Quá hạn');

-- HD3: Đã thanh toán
INSERT INTO HopDong (MaKH, MaNV, SoTienVay, NgayVay, Deadline1, Deadline2, TrangThai)
VALUES (3, 3, 3000000, '2025-04-01', '2025-05-01', '2025-06-01', N'Đã thanh toán');

-- HD4: Gần Deadline2 (nguy cơ thanh lý)
INSERT INTO HopDong (MaKH, MaNV, SoTienVay, NgayVay, Deadline1, Deadline2, TrangThai)
VALUES (4, 1, 15000000, '2025-03-01', '2025-03-31', '2025-04-30', N'Quá hạn');

-- HD5: Mới tạo
INSERT INTO HopDong (MaKH, MaNV, SoTienVay, NgayVay, Deadline1, Deadline2)
VALUES (5, 2, 8000000, '2025-05-01', '2025-06-01', '2025-07-01');

-- Tài sản mẫu
INSERT INTO TaiSan (MaHD, MaDM, TenTS, GiaTriDinhGia, MoTa) VALUES
(1, 1, N'iPhone 14 Pro Max 256GB', 7000000, N'Màu đen, còn 95%, kèm hộp'),
(2, 2, N'Laptop Dell XPS 15', 12000000, N'RAM 16GB SSD 512GB, bàn phím sáng'),
(2, 5, N'Đồng hồ Seiko 5 Sports', 5000000, N'Mặt xanh, dây thép'),
(3, 3, N'Nhẫn vàng 18K 2 chỉ', 3500000, N'Vàng nguyên chất'),
(4, 4, N'Xe máy Honda Wave Alpha', 10000000, N'BKS: 20B1-12345, đời 2022'),
(4, 6, N'Máy ảnh Sony A6400', 8000000, N'Kit 16-50mm, hộp đầy đủ'),
(5, 1, N'Samsung Galaxy S23 Ultra', 10000000, N'256GB, màu xanh');

-- Cập nhật trạng thái tài sản HD3 (đã thanh toán)
UPDATE TaiSan SET TrangThai = N'Đã trả' WHERE MaHD = 3;

-- Giao dịch mẫu
INSERT INTO GiaoDich (MaHD, MaNV, LoaiGD, SoTienThu, DuNoTruoc, DuNoSau, GhiChu) VALUES
(1, 2, N'Trả nợ', 1000000, 5750000, 4750000, N'Trả góp lần 1'),
(3, 3, N'Trả nợ', 3450000, 3450000, 0, N'Thanh toán đủ');

-- Log mẫu
INSERT INTO LogTrangThai (LoaiDoiTuong, MaDoiTuong, TrangThaiCu, TrangThaiMoi, LyDo, NguoiThucHien) VALUES
(N'HopDong', 1, NULL, N'Đang vay', N'Tạo hợp đồng', N'Trần Thị Bình'),
(N'HopDong', 2, NULL, N'Đang vay', N'Tạo hợp đồng', N'Trần Thị Bình'),
(N'HopDong', 2, N'Đang vay', N'Quá hạn', N'Tự động: Quá Deadline1 01/04/2025', N'System'),
(N'HopDong', 3, NULL, N'Đang vay', N'Tạo hợp đồng', N'Lê Minh Phúc'),
(N'HopDong', 3, N'Đang vay', N'Đã thanh toán', N'Khách thanh toán đủ', N'Lê Minh Phúc'),
(N'HopDong', 4, N'Đang vay', N'Quá hạn', N'Tự động: Quá Deadline1 31/03/2025', N'System');


-- ============================================================
-- PHẦN 8: CÁC TRUY VẤN MẪU MINH HỌA
-- ============================================================

-- Q1: Danh sách nợ xấu đầy đủ
-- SELECT * FROM vw_NoxauBaoCao ORDER BY SoNgayQuaHan DESC;

-- Q2: Tổng quan hợp đồng
-- SELECT * FROM vw_HopDongTongHop ORDER BY MaHD;

-- Q3: Tính nợ cụ thể một hợp đồng đến hôm nay
-- SELECT dbo.fn_CalcMoneyContract(2, CAST(GETDATE() AS DATE)) AS TongNo;
-- SELECT dbo.fn_CalcMoneyTransaction(2, CAST(GETDATE() AS DATE)) AS DuNo;

-- Q4: Audit log theo hợp đồng
-- SELECT * FROM LogTrangThai WHERE LoaiDoiTuong = 'HopDong' AND MaDoiTuong = 2 ORDER BY ThoiGian;

PRINT N'✅ Cài đặt CSDL PawnShopDB hoàn tất!';
GO
