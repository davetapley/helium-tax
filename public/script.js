const hotspot = document.querySelector("form");

// listen for the form to be submitted and add a new dream when it is
hotspot.addEventListener("submit", event => {
  // stop our form submission from refreshing the page
  event.preventDefault();

  const address = hotspot.elements.address.value;
  
  fetch('taxes/' + address).then((data) => {
  })
});
