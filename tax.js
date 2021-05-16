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

    let transactionsDoneCount = 0
    let hntSum = 0
    let usdSum = 0
    progress({ transactionsDoneCount, hntSum, usdSum })

    const getRow = async (data) => {
      const { account, amount: { floatBalance: hnt, type: { ticker } }, block, gateway: hotspot, hash, timestamp } = data
      if (ticker !== "HNT") throw "can't handle " + ticker

      const time = moment(timestamp)

      let row = {}
      if (time < firstOracle) {
        if (!warnedFirstOracle) {
          warning('no_oracle', `Some rows will not have a USD value because oracle price wasn't available prior to ${firstOracle.format('MMM Do YYYY')}`)
          warnedFirstOracle = true
        }

        row = { time: time.format(), usd: '', hnt, price: '', account, block, hotspot, hash }
      } else {
        const oraclePrice = await client.oracle.getPriceAtBlock(block)
        const { floatBalance: price, type: { ticker: hntTicker } } = oraclePrice.price
        if (hntTicker !== "USD") throw "can't handle HNT ticker " + hntTicker

        const usd = hnt * price
        row = { time: time.format(), usd, hnt, price, account, block, hotspot, hash }
      }

      transactionsDoneCount += 1 
      hntSum += row.hnt
      usdSum += row.usd == '' ? 0: row.usd
      progress({ transactionsDoneCount, hntSum, usdSum })

      return row
    }

    const params = { minTime: minTime.toDate(), maxTime: maxTime.toDate() }
    const rewards = client.hotspot(address).rewards.list(params)
    let page = await rewards
    const rows = await Promise.all(page.data.map(getRow))

    while (page.hasMore) {
      page = await page.nextPage()
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