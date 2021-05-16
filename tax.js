const moment = require('moment-timezone')
const { Client } = require('@helium/http')
const client = new Client()

const firstOracle = moment({ year: 2020, month: 05, day: 10 })
let warnedFirstOracle = false

const taxes = async (address, year, progress, warning) => {
  console.log("taxes", address, year)
  try {
    const hotspot = await client.hotspots.get(address)
    const { name, lat, lng } = hotspot

    const tzFetch = await fetch(`https://enz4qribbjb5c4.m.pipedream.net?lat=${lat}&lng=${lng}`)
    const tz = await tzFetch.text()
    moment.tz.setDefault(tz);
    console.log("tz", tz)

    const minTime = year === "All" ? moment(0) : moment({ year })
    const maxTime = year === "All" ? moment() : moment({ year }).endOf('year')

    let found = 0
    let done = 0
    progress({ found, done })

    const getRow = async (data) => {
      const { account, amount: { floatBalance: hnt, type: { ticker } }, block, gateway: hotspot, hash, timestamp } = data
      if (ticker !== "HNT") throw "can't handle " + ticker

      const time = moment(timestamp)
      progress({ found, done: done += 1 })

      if (time < firstOracle) {
        if (!warnedFirstOracle) {
          warning('no_oracle', `Some rows will not have a USD value because oracle price wasn't available prior to ${firstOracle.format('MMM Do YYYY')}`)
          warnedFirstOracle = true
        }

        return { time: time.format(), usd: '', hnt, price: '', account, block, hotspot, hash }
      } else {
        const oraclePrice = await client.oracle.getPriceAtBlock(block)
        const { floatBalance: price, type: { ticker: hntTicker } } = oraclePrice.price
        if (hntTicker !== "USD") throw "can't handle HNT ticker " + hntTicker

        const usd = hnt * price
        return { time: time.format(), usd, hnt, price, account, block, hotspot, hash }
      }

    }

    const params = { minTime: minTime.toDate(), maxTime: maxTime.toDate() }
    const rewards = client.hotspot(address).rewards.list(params)
    let page = await rewards
    progress({ done, found: found += page.data.length })
    const rows = await Promise.all(page.data.map(getRow))

    while (page.hasMore) {
      page = await page.nextPage()
      console.log("amount", page.data.length)
      progress({ done, found: found += page.data.length })
      const newRows = await Promise.all(page.data.map(getRow))

      rows.push(...newRows)
    }

    return { name, tz, rows }
  } catch (e) {
    console.log(e)
    warning(`hotspot-${e.response.status}`, "Couldn't find hotspot, use address (e.g. a1b2c3d4e5f6..) and not name (e.g. three-funny-words)")
    throw (e)
  }
}

module.exports = taxes