#! /usr/bin/node

// This script removes the "leap_latest" item from the build matrix if it is
// present. It uses NodeJS because the YAML library can keep the original
// comments in the file and does not interpret special YAML values like "on".
//
// See more details in https://eemeli.org/yaml 

const fs = require("fs");
const YAML = require("yaml");

const file = process.argv[2];
if (!file) {
  console.error("Missing path to the YML file");
  process.exit(1);
}

try {
  const data = fs.readFileSync(file, "utf-8");
  const doc = YAML.parseDocument(data);

  const jobs = doc.get("jobs");
  let modified = false;

  if (jobs) {
    jobs.items.forEach(job => {
      const distro = job.value?.get("strategy")?.get("matrix")?.get("distro");

      if (distro) {
        const distroItems = distro.items;
        // the distro contains only one item, if it is Leap then switch it to
        // Tumbleweed
        if (distroItems.length === 1) {
          if (distroItems[0].value === "leap_latest") {
            distroItems[0].value = "tumbleweed";
            modified = true;
          }
        } else if (distroItems.length > 1) {
          // if there are multiple items remove the Leap value from the list
          // (the other one should be Tumbleweed)
          if (distroItems.find(d => d.value === "leap_latest")) {
            distro.items = distroItems.filter(d => d.value !== "leap_latest");
            modified = true;
          }
        }
      }
    });
    
    if (modified) {
      fs.writeFileSync(file, doc.toString(), "utf-8");
      console.log(`File ${file} updated`);
    }
  }
}
catch (error) {
  console.error("ERROR: ", error.message);
  process.exit(1);
}
