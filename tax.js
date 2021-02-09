const geoTz = require('geo-tz')
const moment = require('moment-timezone')
const { Client } = require('@helium/http')
const client = new Client()

const taxes = async (address, cb) => {
  console.log("taxes", address)
  const hotspot = await client.hotspots.get(address)
  const { name, lat, lng } = hotspot

  const tz = geoTz(lat, lng)[0]
  moment.tz.setDefault(tz);
  console.log("tz", tz)

  const minTime = moment({ year: 2020 }).toDate()
  const maxTime = moment(minTime).endOf('year').toDate()

  let found = 0
  let done = 0
  cb({ found, done })

  const getRow = async (data) => {
    const { account, amount: { floatBalance: hnt, type: { ticker } }, block, gateway: hotspot, hash, timestamp } = data
    if (ticker !== "HNT") throw "can't handle " + ticker
    const oraclePrice = await client.oracle.getPriceAtBlock(block)

    const { floatBalance: price, type: { ticker: hntTicker } } = oraclePrice.price
    if (hntTicker !== "USD") throw "can't handle HNT ticker " + hntTicker

    const time = moment(timestamp).format();
    const usd = hnt * price
    console.log(time, usd)
    cb({ found, done: done += 1 })
    return { time, usd, hnt, price, account, block, hotspot, hash }
  }

  const params = { minTime, maxTime }
  const rewards = client.hotspot(address).rewards.list(params)
  let page = await rewards
  cb({ done, found: found += page.data.length })
  const rows = await Promise.all(page.data.map(getRow))

  while (page.hasMore) {
    page = await page.nextPage()
    console.log("amount", page.data.length)
    cb({ done, found: found += page.data.length })
    const newRows = await Promise.all(page.data.map(getRow))

    rows.push(...newRows)
  }

  return { name, tz, rows }
}

module.exports = taxes