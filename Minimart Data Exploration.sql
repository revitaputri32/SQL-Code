-- Eksplorasi Dataset Minimart
USE minimart;

-- Daftar nama cabang dan kota
# Data berasal dari tiga kota yaitu Makassar, Jakarta Pusat, dan Surabaya
# Di setiap kota hanya terdapat satu cabang yang memiliki data penjualan
WITH kota_cabang_penjualan as(
	SELECT distinct
		mk.nama_kota,
		mc.nama_cabang
	FROM ms_kota mk JOIN ms_cabang mc
	ON mk.kode_kota = mc.kode_kota
	JOIN tr_penjualan tp 
	ON mc.kode_cabang = tp.kode_cabang
)
SELECT 
	kcp.nama_kota,
	kcp.nama_cabang AS cabang_penjualan,
	ctp.daftar_cabang AS cabang_tidak_jualan
FROM kota_cabang_penjualan kcp JOIN cabang_tanpa_penjualan ctp
	ON kcp.nama_kota = ctp.nama_kota;

-- 	Penjualan (qty) cabang dibandingkan dengan total penjualan seluruh cabang
WITH penjualan_per_cabang AS (
	SELECT 
		mk.nama_kota,
		mc.kode_cabang,
		sum(jumlah_pembelian) AS jumlah_penjualan_cabang,
		(SELECT sum(jumlah_pembelian) FROM tr_penjualan) AS total_penjualan
	FROM tr_penjualan tp JOIN ms_cabang mc
		ON tp.kode_cabang = mc.kode_cabang
	JOIN ms_kota mk 
		ON mc.kode_kota = mk.kode_kota 
	GROUP BY 1,2	
)
SELECT 
	nama_kota,
	jumlah_penjualan_cabang,
	total_penjualan,
	round((jumlah_penjualan_cabang/total_penjualan)*100, 2) AS pct_penjualan_cabang,
	RANK() OVER(ORDER BY jumlah_penjualan_cabang desc) AS urutan_cabang
FROM penjualan_per_cabang;

-- Trend transaksi bulanan setiap cabang
WITH transaksi_bulan AS (
	SELECT 
		MONTH(tgl_transaksi) AS bulan,
		kode_cabang,
		count(kode_transaksi) AS jumlah_transaksi,
		LAG(count(kode_transaksi),1) over(PARTITION BY kode_cabang ORDER BY MONTH(tgl_transaksi)) AS previous_jumlah_transaksi
	FROM tr_penjualan
	GROUP BY 1,2
) 
SELECT 
	bulan,
	kode_cabang,
	jumlah_transaksi,
	previous_jumlah_transaksi,
	round((jumlah_transaksi-previous_jumlah_transaksi)/previous_jumlah_transaksi*100, 2) AS rate_transaksi,
	CASE 
		WHEN ((jumlah_transaksi-previous_jumlah_transaksi)/previous_jumlah_transaksi*100) > 0 THEN 'Positif'
		WHEN ((jumlah_transaksi-previous_jumlah_transaksi)/previous_jumlah_transaksi*100) < 0 THEN 'Negatif'
		ELSE 'No data'
	END AS keterangan
FROM transaksi_bulan;

-- Trend profit bulanan setiap cabang
SELECT 
	*,
	round((profit - previous_profit)/previous_profit*100, 2) AS pct_selisih_profit,
	CASE 
		WHEN round((profit - previous_profit)/previous_profit*100, 2) < 0 THEN 'Turun'
		WHEN round((profit - previous_profit)/previous_profit*100, 2) > 0 THEN 'Naik'
		ELSE 'No data'
	END AS keterangan
FROM (
SELECT 
	MONTH(tp.tgl_transaksi) AS bulan,
	tp.kode_cabang,
	sum((mhh.harga_berlaku_cabang - mhh.modal_cabang - mhh.biaya_cabang) * tp.jumlah_pembelian) AS profit,
	lag(sum((mhh.harga_berlaku_cabang - mhh.modal_cabang - mhh.biaya_cabang) * tp.jumlah_pembelian)) 
		over(PARTITION BY kode_cabang ORDER BY MONTH(tp.tgl_transaksi)) AS previous_profit
FROM tr_penjualan tp
LEFT JOIN ms_harga_harian mhh ON tp.tgl_transaksi = mhh.tgl_berlaku
AND tp.kode_cabang = mhh.kode_cabang
AND tp.kode_produk = mhh.kode_produk
GROUP BY 1, 2 ) AS profit_bulanan;

-- Profit produk dari seluruh cabang
# Produk dikelompokkan ke dalam 4 grup berdasarkan profit (grup 1 paling profitable) 
WITH profit_produk AS (
SELECT
	mhh.kode_cabang,
	mhh.kode_produk,
	mp.nama_produk, 
	sum((mhh.harga_berlaku_cabang - (mhh.modal_cabang + mhh.biaya_cabang)) * tp.jumlah_pembelian) AS profit_per_produk
FROM tr_penjualan tp
LEFT JOIN ms_harga_harian mhh ON tp.tgl_transaksi = mhh.tgl_berlaku
AND tp.kode_cabang = mhh.kode_cabang
AND tp.kode_produk = mhh.kode_produk
LEFT JOIN ms_produk mp ON tp.kode_produk = mp.kode_produk 
GROUP BY 1,2,3)
SELECT 
	kode_cabang,
	nama_produk,
	profit_per_produk,
	NTILE(4) OVER(ORDER BY profit_per_produk desc) AS group_produk
FROM profit_produk;

-- Karyawan dengan transaksi paling banyak (best performing)
WITH transaksi_karyawan AS (
SELECT
	tp.kode_cabang,
	tp.kode_kasir,
	concat(mkar.nama_depan,' ',mkar.nama_belakang) AS nama_panjang,
	count(tp.kode_transaksi) AS transaksi,
	rank() over(PARTITION BY tp.kode_cabang ORDER BY count(tp.kode_transaksi) desc) AS urutan
FROM tr_penjualan tp JOIN ms_karyawan mkar 
	ON tp.kode_kasir = mkar.kode_karyawan
GROUP BY 1,2,3
),
transaksi_cabang AS (
SELECT distinct
	kode_cabang,
	kode_kasir,
	count(*) OVER(PARTITION BY kode_cabang) AS total_transaksi_cabang
FROM tr_penjualan
),
daftar_kota AS (
SELECT DISTINCT 
	mk.nama_kota,
	mc.kode_cabang,
	tp.kode_kasir
FROM ms_kota mk JOIN ms_cabang mc
ON mk.kode_kota = mc.kode_kota
JOIN tr_penjualan tp 
ON mc.kode_cabang = tp.kode_cabang
)
SELECT
	dk.nama_kota,
	tk.nama_panjang,
	round((tk.transaksi/tc.total_transaksi_cabang*100),2) AS pct_transaksi_karyawan,
	tk.urutan
FROM transaksi_karyawan tk JOIN transaksi_cabang tc
	ON tk.kode_kasir = tc.kode_kasir
	JOIN daftar_kota dk ON tc.kode_kasir = dk.kode_kasir
WHERE tk.urutan IN (1,2,3)
ORDER BY 1,4;