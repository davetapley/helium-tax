const tax = require('./tax')

const form = document.querySelector("form");
const progress = document.querySelector("#progress");
const warning = document.querySelector("#warning");

form.addEventListener("submit", event => {
  event.preventDefault();

  gtag('event', 'submit')

  const hotspots = new Set()
  let transactionCount = 0
  let hntSum = 0
  let usdSum = 0
  const progressCB = ({ hotSpotAddress, hnt, usd }) => {
    hotspots.add(hotSpotAddress)
    transactionCount += 1
    hntSum += hnt
    usdSum += usd
    const hotspotCount = (hotspots.size > 1) ? `${hotspots.size} hotspots / ` : ""
    progress.innerHTML = hotspotCount + `${transactionCount} transactions / ${hntSum.toFixed(0)} HNT / $${usdSum.toFixed(2)} income`
  }

  const warningCB = (kind, message) => {
    const li = document.createElement("li");
    li.appendChild(document.createTextNode(message));
    gtag('event', kind)
    warning.appendChild(li)
  }

  const address = form.elements.address.value;
  const year = form.elements.year.value;
  tax(address, year, progressCB, warningCB).then((rows) => {
    gtag('event', 'success')
    progress.innerHTML += ' ✅'

    const header = `${Object.keys(rows[0]).join(',')}\n`
    const values = rows.reverse().map((row) => `${Object.values(row).join(',')}\n`)
    const csv = [header].concat(values)
    var a = window.document.createElement('a');
    a.style.display = 'none';
    a.href = window.URL.createObjectURL(new Blob(csv, { type: 'text/csv' }));
    a.download = `${address}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  }).finally(() => {
    progress.classList.add('done')
  })
  progress.classList.add('active')
})
