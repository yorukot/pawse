(() => {
  const textAttributes = "[data-release-text]";
  const linkAttributes = "[data-release-href]";

  const applyRelease = (release) => {
    const values = {
      ...release,
      accessLabel: release.earlyAccess ? "Early access" : "Stable release"
    };

    document.querySelectorAll(textAttributes).forEach((element) => {
      const key = element.dataset.releaseText;
      if (values[key] !== undefined) {
        element.textContent = String(values[key]);
      }
    });

    document.querySelectorAll(linkAttributes).forEach((element) => {
      const key = element.dataset.releaseHref;
      if (typeof values[key] === "string") {
        element.href = values[key];
      }
    });

    if (release.notarized) {
      document.querySelectorAll('[data-release-visibility="notNotarized"]').forEach((element) => {
        element.hidden = true;
      });
    }
  };

  fetch("/release.json", { cache: "no-store" })
    .then((response) => response.ok ? response.json() : Promise.reject())
    .then(applyRelease)
    .catch(() => {});
})();
