const getPrice = require('./prices');

test('block too new', () => {
  const getNew = () => (getPrice(1727203))
  expect(getNew).toThrow("block not in prices.json")
});

test('block too old', () => {
  const getOld = () => (getPrice(10))
  expect(getOld).toThrow("block not in prices.json")
});

test('block just right', () => {
  expect((getPrice(998155))).toBe(23.48000000)
});