const tax = require('./tax')

const form = document.querySelector("form");
const progress = document.querySelector("#progress");
const current = document.querySelector("#current");

form.addEventListener("submit", event => {
  event.preventDefault();

  gtag('event', 'submit')

  const cb = ({ found, done }) => {
    console.log(found, done)
    current.innerHTML = `${done} / ${found} transactions`
  }

  const address = form.elements.address.value;
  tax(address, cb).then(({ name, rows }) => {
    progress.classList.add('done')
    current.innerHTML += ' ✅'

    const header = `${Object.keys(rows[0]).join(',')}\n`
    const values = rows.reverse().map((row) => `${Object.values(row).join(',')}\n`)
    const csv = [header].concat(values)
    var a = window.document.createElement('a');
    a.style.display = 'none';
    a.href = window.URL.createObjectURL(new Blob(csv, { type: 'text/csv' }));
    a.download = `${name}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  })
  progress.classList.add('active')
})
