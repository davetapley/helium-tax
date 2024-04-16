# HNT Tax 2023 and beyond

## Requirements

### Export transaction data

Sign up for [Hotspotty](https://app.hotspotty.net/) and [add your wallet](https://docs.hotspotty.net/getting-started/manage-wallets).

I'm not affiliated with Hotspotty, but I found it is [cheapest](https://app.hotspotty.net/pricing) and easiest for exporting.


### Get database tool

Download [duckdb](https://duckdb.org/docs/installation/?version=stable) command line tool (free).

Open a terminal / command prompt and `cd` to the folder where you downloaded `rewards.csv` and `duckdb`.

Run:
```bash
./duckdb rewards.db
```

### Get transactions in to database

[Export your data](https://docs.hotspotty.net/features/payment-management/tax-reporting) in Hotspotty, choosing date range Jan 1 2023 to Jan 1 2024 (we will filter to correct time zone later, this is to ensure we get everything, as Hotspotty uses UTC time).

Download the CSV file, rename it to `rewards.csv` and move it to where you unzipped the `duckdb` to.

Import `rewards.csv` into the database:

```sql
CREATE TABLE rewards AS SELECT Token AS token, to_timestamp("Start Date") AS time, Amount AS amount FROM read_csv_auto('rewards.csv');
```

Filter date to your local time zone (since hotspotty exports in UTC, and `duckdb` will use your local zone):

```sql
DELETE FROM rewards WHERE time < '2023-01-01';
DELETE FROM rewards WHERE time >= '2024-01-01';
```

Verify which tokens you have:

```sql
SELECT distinct(token) FROM rewards;
```

I will assume you see `HNT` and `IOT` in the output, split on those:

```sql
CREATE VIEW iot_rewards AS SELECT time, amount FROM rewards WHERE token = 'iot';
CREATE VIEW hnt_rewards AS SELECT time, amount FROM rewards WHERE token = 'hnt';
```

For a sanity check verify no overlap on the [HNT to IOT migration](https://docs.helium.com/solana/migration/hotspot-operator/) on April 18, 2023:

```sql
SELECT max(time) FROM hnt_usd_rewards;
SELECT min(time) FROM iot_usd_rewards;
```

You should see e.g. `2023-04-18 09:28:25-07` and `2023-04-24 17:00:00-07` (times may vary, dates should be same / close).


### Get price data in to database

Download price data:
* https://finance.yahoo.com/quote/HNT-USD/history/?period1=1672531200&period2=1703980800
* https://finance.yahoo.com/quote/IOT-USD/history/?period1=1672531200&period2=1703980800

Move the downloaded `HNT-USD.csv` and `IOT-USD.csv` to the same folder as `rewards.csv` and `duckdb`.

Import in to database:

```sql
CREATE TABLE iot_usd AS SELECT "Date" AS date, ("High" + "Low") / 2 AS price FROM read_csv_auto('IOT-USD.csv');
CREATE TABLE hnt_usd AS SELECT "Date" AS date, ("High" + "Low") / 2 AS price FROM read_csv_auto('HNT-USD.csv');
```

Join prices with your rewards:

```sql
CREATE VIEW iot_usd_rewards AS SELECT time, amount, price, amount * price AS usd FROM iot_rewards ASOF JOIN iot_usd ON time > date;
CREATE VIEW hnt_usd_rewards AS SELECT time, amount, price, amount * price AS usd FROM hnt_rewards ASOF JOIN hnt_usd ON time > date;
```

Summarize your rewards in USD:

```sql
SELECT sum(usd) FROM iot_usd_rewards;
SELECT sum(usd) FROM hnt_usd_rewards;
```

Add these two numbers together to get your total rewards in USD in 2023.

You are done.
