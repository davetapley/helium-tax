const express = require("express");
const app = express();

const geoTz = require('geo-tz')
const moment = require('moment-timezone')
const { Client } = require('@helium/http')
const client = new Client()

const taxes = async (address) => {
  console.log("taxes", address)
  const hotspot = await client.hotspots.get(address)
  const { name, lat, lng } = hotspot

  const tz = geoTz(lat, lng)[0]
  moment.tz.setDefault(tz);
  console.log("tz", tz)

  const minTime = moment({ year: 2021 }).toDate()
  const maxTime = moment(minTime).endOf('day').toDate()
  
  const getAmount = async ({ amount: { floatBalance, type: { ticker } }, timestamp, block }) => {
    if (ticker !== "HNT") throw "can't handle " + ticker
    const oraclePrice = await client.oracle.getPriceAtBlock(block)
    
    const { floatBalance: hntFloatBalance, type: { ticker: hntTicker } } = oraclePrice.price
    if (hntTicker !== "USD") throw "can't handle HNT ticker " + hntTicker

    const time = moment(timestamp).format();
    const reward = floatBalance * hntFloatBalance
    console.log(time, reward)
    return {time, reward}
  }

  const params = { minTime, maxTime }
  const rewards = client.hotspot(address).rewards.list(params)
  let page = await rewards
  const amounts = await Promise.all(page.data.map(getAmount))

  while (page.hasMore) {
    page = await page.nextPage()
    const newAmounts = await Promise.all(page.data.map(getAmount))
    console.log("amount", amounts.length)

    amounts.push(...newAmounts)
  }

  return {name, tz, amounts}
}

app.use(express.static("public"));

app.get("/", (request, response) => {
  response.sendFile(__dirname + "/views/index.html");
});

app.get("/taxes/:address", async (request, response) => {
  const foo = await taxes(request.params.address)
  response.send(foo)
});

const listener = app.listen(process.env.PORT, () => {
  console.log("Your app is listening on port " + listener.address().port);
});
