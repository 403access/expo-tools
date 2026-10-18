(function () {
  "use strict";

  // Frosted nav once the page scrolls.
  var nav = document.getElementById("nav");
  function onScroll() {
    if (!nav) return;
    nav.classList.toggle("scrolled", window.scrollY > 12);
  }
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  // Copy-to-clipboard buttons.
  document.querySelectorAll(".copy").forEach(function (button) {
    button.addEventListener("click", function () {
      var value = button.getAttribute("data-copy") || "";
      var done = function () {
        var previous = button.textContent;
        button.textContent = "Copied";
        button.classList.add("copied");
        window.setTimeout(function () {
          button.textContent = previous;
          button.classList.remove("copied");
        }, 1600);
      };

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(value).then(done, fallback);
      } else {
        fallback();
      }

      function fallback() {
        var area = document.createElement("textarea");
        area.value = value;
        area.setAttribute("readonly", "");
        area.style.position = "fixed";
        area.style.opacity = "0";
        document.body.appendChild(area);
        area.select();
        try {
          document.execCommand("copy");
          done();
        } catch (error) {
          /* clipboard unavailable */
        }
        document.body.removeChild(area);
      }
    });
  });

  // Reveal-on-scroll.
  var revealables = document.querySelectorAll(".reveal");
  if (!("IntersectionObserver" in window)) {
    revealables.forEach(function (element) {
      element.classList.add("visible");
    });
    return;
  }

  var observer = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { rootMargin: "0px 0px -12% 0px", threshold: 0.08 }
  );

  revealables.forEach(function (element) {
    observer.observe(element);
  });
})();
