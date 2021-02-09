const tax = require('./tax')

const form = document.querySelector("form");
const progress = document.querySelector("#progress");
const warning = document.querySelector("#warning");

form.addEventListener("submit", event => {
  event.preventDefault();

  gtag('event', 'submit')

  const progressCB = ({ done }) => {
    progress.innerHTML = `Found ${found} transactions`
  }

  const warningCB = (message) => {
    const li = document.createElement("li");
    li.appendChild(document.createTextNode(message)); 
    warning.appendChild(li)
  }

  const address = form.elements.address.value;
  tax(address, progressCB, warningCB).then(({ name, rows }) => {
    progress.classList.add('done')
    progress.innerHTML += ' ✅'

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
