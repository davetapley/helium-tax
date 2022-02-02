const moment = require('moment-timezone')
const { Client } = require('@helium/http')
const client = new Client()

const firstOracle = moment({ year: 2020, month: 5, day: 10 })
let warnedFirstOracle = false

const addressTaxes = async (address, year, progress, warning) => {
  try {
    // See if this is hotspot address
    await client.hotspots.get(address)
    return await hotspotTaxes(address, year, progress, warning)
  } catch (e) {
    try {
      // See if this is validator address
      await client.validators.get(address)
      return await hotspotTaxes(address, year, progress, warning, undefined, true)
    } catch (e) {
      try {
        // See if this is account address
        const account = await client.accounts.get(address)
        const { hotspots } = await account.hotspots.fetchList()

        const withLocation = hotspots.filter(({ lat }) => lat)
        if (hotspots.length !== withLocation.length) {
          warning('no-location', "At least one hotspot has no location and will be omitted from results")
        }
        const rows = await Promise.all(withLocation.map(({ address }) => hotspotTaxes(address, year, progress, warning)))
        return rows.flat()
      } catch (e) {
        if (e.response) {
          warning(`address-${e.response.status}`, "Couldn't find address, use (e.g. a1b2c3d4e5f6..) and not name (e.g. three-funny-words)")
        }
        throw (e)
      }
    }
  }
}

const hotspotTaxes = async (hotSpotAddress, year, progress, warning, rows = [], isValidator) => {
  console.log("taxes", hotSpotAddress, year)
  const hotspot = isValidator
      ? await client.validators.get(hotSpotAddress)
      : await client.hotspots.get(hotSpotAddress)

  if (!isValidator) {
    const { lat, lng } = hotspot
    const tzFetch = await fetch(`https://enz4qribbjb5c4.m.pipedream.net?lat=${lat}&lng=${lng}`)
    const tz = await tzFetch.text()
    moment.tz.setDefault(tz);
    console.log("tz", tz)
  }

  const minTime = year === "All" ? moment(0) : moment({ year })
  const maxTime = year === "All" ? moment() : moment({ year }).endOf('year')

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

    progress({ hotSpotAddress, hnt: row.hnt, usd: row.usd === '' ? 0 : row.usd })

    return row
  }

  const params = { minTime: minTime.toDate(), maxTime: maxTime.toDate() }
  const rewards = hotspot.rewards.list(params)
  let page = await rewards
  const newRows = await Promise.all(page.data.map(getRow))
  rows.push(...newRows)

  while (page.hasMore) {
    page = await page.nextPage()
    const newRows = await Promise.all(page.data.map(getRow))

    rows.push(...newRows)
  }

  return rows

}

module.exports = addressTaxes
