const tax = require('./tax')

const form = document.querySelector("form");
const progress = document.querySelector("#progress");
const current = document.querySelector("#current");

form.elements.address.value = '112ChG5vb21nE2wn4x4DYzDnG1VDCaRTbxrRXeBLkg2VFgEuWYfV'
// listen for the form to be submitted and add a new dream when it is
form.addEventListener("submit", event => {
  // stop our form submission from refreshing the page
  event.preventDefault();

  const cb = ({ found, done }) => {
    console.log(found, done)
    current.innerHTML = `${done} / ${found} transactions`
  }

  const address = form.elements.address.value;
  tax(address, cb).then(({ name, amounts }) => {
    progress.classList.add('done')
    current.innerHTML += ' ✅'

    const csv = amounts.reverse().map(({ time, reward }) => `${time},${reward}\n`)
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
