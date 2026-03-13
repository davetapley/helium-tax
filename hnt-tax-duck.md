# HNT / IOT Tax 2023 and beyond

Disclaimer: Provided AS IS, see license below. Do your own research.

## Requirements

### Export transaction data

Sign up for [Hotspotty](https://app.hotspotty.net/) and [add your wallet](https://docs.hotspotty.net/getting-started/manage-wallets).

I'm not affiliated with Hotspotty, but I found it is [cheapest](https://app.hotspotty.net/pricing) and easiest for exporting.


### Get database tool

Download [duckdb](https://duckdb.org/docs/installation/?version=stable) command line tool (free).

Open a terminal / command prompt and `cd` to the folder where you unzipped `duckdb` (`duckdb.exe` on Windows).

Run (Mac / Linux):
```bash
./duckdb rewards.db
```

Run (Windows)
```
./duckdb.exe rewards.db
```

### Get transactions in to database

[Export your data](https://docs.hotspotty.net/features/payment-management/tax-reporting) in Hotspotty, choosing date range Jan 1 2025 to Jan 1 2026 (we will filter to correct time zone later, this is to ensure we get everything, as Hotspotty uses UTC time).

Download the CSV file, rename it to `rewards.csv` and move it to where you unzipped the `duckdb` to.

Import `rewards.csv` into the database:

```sql
CREATE TABLE rewards AS SELECT Token AS token, to_timestamp("Start Date") AS time, Amount AS amount FROM read_csv_auto('rewards.csv');
```

Filter date to 2025:

```sql
DELETE FROM rewards WHERE extract('year' FROM time) <> 2025;
```

Verify which tokens you have:

```sql
SELECT distinct(token) FROM rewards;
```

For tax year **2025** only: You will have both `IOT` and `HNT` in the output due to [HIP 138](https://blog.helium.com/hnt-returns-implementation-updates-and-community-q-a-on-hip-138-334aef394f48).



### Get price data in to database

Download price data for IOT and HNT as csv (via ↓ icon on far right of header):

https://www.coingecko.com/en/coins/helium-iot/historical_data
https://www.coingecko.com/en/coins/helium/historical_data


Move the downloaded `iot-usd-max.csv` and  `hnt-usd-max.csv`  to the same folder as `rewards.csv` and `duckdb`.

Import in to database:

```sql
CREATE TABLE iot_usd AS SELECT snapped_at AS date, price FROM read_csv_auto('iot-usd-max.csv');
CREATE TABLE hnt_usd AS SELECT snapped_at AS date, price FROM read_csv_auto('hnt-usd-max.csv');


DELETE FROM iot_usd WHERE extract('year' FROM date) <> 2025;
DELETE FROM hnt_usd WHERE extract('year' FROM date) <> 2025;
```

Join prices for each token with your rewards:

```sql
CREATE VIEW iot_usd_rewards AS SELECT time, amount * price AS usd FROM rewards ASOF JOIN iot_usd ON time >= date WHERE token = iot';
CREATE VIEW hnt_usd_rewards AS SELECT time, amount * price AS usd FROM rewards ASOF JOIN hnt_usd ON time >= date WHERE token = 'hnt';
```

Summarize your rewards in USD:

```sql
SELECT sum(usd) FROM iot_usd_rewards;
SELECT sum(usd) FROM hnt_usd_rewards;
```

Add these numbers for your total rewards in USD in 2025.

You are done.


# License


Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

aka [MIT License](https://github.com/davetapley/helium-tax/blob/main/LICENSE).
