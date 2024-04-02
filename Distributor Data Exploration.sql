USE dwh_phi;

# Data dikumpulkan selama satu bulan dari 2018-01-01 hingga 2018-01-31

-- Laporan Delivery Order
SELECT
    td.no_do,
    ts.kode_customer,
    td.tgl_do,
    CASE
		WHEN ts.satuan = 'krat' THEN ts.qty * 24
	    WHEN ts.satuan = 'dus' THEN ts.qty * 30
	    ELSE ts.qty
	END AS qty,
    round(
    	(
    	 CASE
         	WHEN ts.satuan = 'krat' THEN ts.qty * 24
            WHEN ts.satuan = 'dus' THEN ts.qty * 30
            ELSE ts.qty
         END
        ) * (
             SELECT mp.harga_satuan
             FROM ms_product mp
             WHERE ts.kode_barang = mp.kode_produk
            ) * 1.1
    + (
        SELECT mc.ongkos_kirim
        FROM ms_customer mc
        WHERE ts.kode_customer = mc.kode_customer
      ),0) AS total_penjualan
FROM tr_do td
JOIN tr_so ts ON td.no_entry_so = ts.no_entry_so
ORDER BY no_do;

-- Laporan umur hutang pelanggan per 2018-02-01
SELECT
    td.no_do,
    (
        SELECT mc.nama_customer
        FROM tr_so ts
        JOIN ms_customer mc ON ts.kode_customer = mc.kode_customer
        WHERE ts.no_entry_so = td.no_entry_so
    ) AS nama_customer,
    td.tgl_do,
    CAST('2018-02-01' AS date) AS date_measurement,
    DATEDIFF('2018-02-01', td.tgl_do) AS aging
FROM tr_do td
LEFT JOIN tr_inv ti ON td.no_entry_do = ti.no_entry_do
WHERE ti.no_inv IS NULL
ORDER BY aging DESC, no_do;

-- Produk paling laris berdasarkan kuantitas
WITH qty_produk AS (
	SELECT 
	ts.no_so, 
	mp.nama_product nama_product,
	CASE 
		WHEN ts.satuan = 'krat' THEN ts.qty*24
		WHEN ts.satuan = 'dus' THEN ts.qty*30
		ELSE ts.qty
	END AS qty
	FROM tr_so ts JOIN ms_product mp 
	ON ts.kode_barang = mp.kode_produk
)
SELECT 
	DISTINCT nama_product,
	sum(qty) OVER (PARTITION BY nama_product) qty
FROM qty_produk
ORDER BY 2 DESC;

-- Performa vendor
SELECT 
    mv.vendor,
    SUM(
        CASE 
            WHEN ts.satuan = 'krat' THEN ROUND(mp.harga_satuan * ts.qty * 24)
            WHEN ts.satuan = 'dus' THEN ROUND(mp.harga_satuan * ts.qty * 30)
            ELSE ROUND(mp.harga_satuan * ts.qty)
        END 
    ) AS nilai_penjualan
FROM tr_inv ti
JOIN tr_do td ON td.no_entry_do = ti.no_entry_do
JOIN tr_so ts ON ts.no_entry_so = td.no_entry_so
JOIN ms_product mp ON mp.kode_produk = ts.kode_barang
JOIN ms_vendor mv ON mv.kode_vendor = mp.kode_vendor
GROUP BY 1
ORDER BY nilai_penjualan DESC, vendor;

-- Performa Pegawai
SELECT
	mp.nama_pegawai,
	mp.jabatan, 
	count(DISTINCT ts.no_so) AS sales,
	mp.target,
	IF(count(DISTINCT ts.no_so) >= mp.target, 'Mencapai', 'Tidak Mencapai') AS pencapaian_target
FROM tr_so ts 
JOIN ms_pegawai mp ON ts.kode_sales = mp.kode_pegawai
GROUP BY 1,2,4
ORDER BY 1; 

