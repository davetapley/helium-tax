const data = require('./prices.json')

const latestBlock = data[0][0]
const oldestBlock = data[data.length - 1][0]

const getPrice = (block) => {
    console.log("getPrice " + block)
    if (block < oldestBlock || block > latestBlock) {
        throw new RangeError("block not in prices.json")
    }

    const match = data.find(([_block, _price]) => _block < block)
    return match[1] / 100000000.0
}

module.exports = getPrice