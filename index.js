const geoTz = require('geo-tz')
const moment = require('moment-timezone')
const { Client } = require('@helium/http')
const client = new Client()

const url = new URL(event.url)
const address = url.pathname.slice(1)
let body = ""

const f = async () => {
  const hotspot = await client.hotspots.get(address)
  const { name, lat, lng } = hotspot
  body += 'Hotspot,' + name

  const tz = geoTz(lat, lng)[0]
  body += "\nAssumed timezone," + tz + "\n\n"
  moment.tz.setDefault(tz);

  const minTime = moment({ year: 2020 }).toDate()
  const maxTime = moment(minTime).endOf('year').toDate()

  body += "\n,HNT rewarded,HNT/USD,USD rewarded\n"

  const getAmount = async ({ amount: { floatBalance, type: { ticker } }, timestamp, block }) => {
    if (ticker !== "HNT") throw "can't handle " + ticker

    const oraclePrice = await client.oracle.getPriceAtBlock(block)
    const { floatBalance: hntFloatBalance, type: { ticker: hntTicker } } = oraclePrice.price
    if (hntTicker !== "USD") throw "can't handle HNT ticker " + hntTicker

    const time = moment(timestamp).format();
    const reward = floatBalance * hntFloatBalance
    return [time, floatBalance, hntFloatBalance, reward]
  }

  const params = { minTime, maxTime }
  const rewards = client.hotspot(address).rewards.list(params)
  let page = await rewards
  const amounts = await Promise.all(page.data.map(getAmount))

  while (page.hasMore) {
    page = await page.nextPage()
    const newAmounts = await Promise.all(page.data.map(getAmount))
    amounts.push(...newAmounts)
  }

  body += amounts.reverse().map((row) => row.join(",")).join("\n")
  const headers = { 
    'Content-disposition': 'attachment; filename=' + name + '.csv',
    'Content-Type': 'text/csv' }
  $respond({ status: 200, headers, body })
}

if(address.length > 0 && address !== 'favicon.ico') {
  await f()
} else {
  $respond({status: 404})
}