// karpachess.com — the menu, the device tabs, the screenshot strip and its
// lightbox. No dependencies, nothing loaded from elsewhere, nothing stored.
(function () {
  "use strict";

  /* ───────── Menu (narrow windows) ───────── */
  var toggle = document.getElementById("navToggle");
  var menu = document.getElementById("navMenu");

  function setMenu(open) {
    menu.classList.toggle("open", open);
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
  }

  if (toggle && menu) {
    toggle.addEventListener("click", function () {
      setMenu(!menu.classList.contains("open"));
    });
    menu.addEventListener("click", function (e) {
      if (e.target.tagName === "A") setMenu(false);
    });
    // A tap anywhere outside the open menu closes it.
    document.addEventListener("click", function (e) {
      if (menu.classList.contains("open") && !e.target.closest(".nav")) setMenu(false);
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && menu.classList.contains("open")) {
        setMenu(false);
        toggle.focus();
      }
    });
  }

  /* ───────── Device tabs ───────── */
  var tabs = Array.prototype.slice.call(document.querySelectorAll(".tabs__tab"));

  function activePanel() {
    return document.querySelector(".shots:not([hidden])");
  }

  function select(tab) {
    tabs.forEach(function (other) {
      var on = other === tab;
      other.setAttribute("aria-selected", on ? "true" : "false");
      other.tabIndex = on ? 0 : -1;
      document.getElementById(other.getAttribute("aria-controls")).hidden = !on;
    });
    updateSteps();
  }

  tabs.forEach(function (tab, i) {
    tab.addEventListener("click", function () { select(tab); });
    tab.addEventListener("keydown", function (e) {
      var step = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
      if (!step) return;
      var next = tabs[(i + step + tabs.length) % tabs.length];
      select(next);
      next.focus();
    });
  });

  /* ───────── Strip arrows ───────── */
  var back = document.querySelector(".gallery__step--back");
  var forward = document.querySelector(".gallery__step--next");

  function updateSteps() {
    var strip = activePanel();
    if (!strip || !back || !forward) return;
    back.disabled = strip.scrollLeft <= 4;
    forward.disabled = strip.scrollLeft + strip.clientWidth >= strip.scrollWidth - 4;
  }

  function scrollStrip(direction) {
    var strip = activePanel();
    if (strip) strip.scrollBy({ left: direction * strip.clientWidth * 0.8, behavior: "smooth" });
  }

  if (back && forward) {
    back.addEventListener("click", function () { scrollStrip(-1); });
    forward.addEventListener("click", function () { scrollStrip(1); });
    Array.prototype.forEach.call(document.querySelectorAll(".shots"), function (strip) {
      strip.addEventListener("scroll", updateSteps, { passive: true });
    });
    window.addEventListener("resize", updateSteps);
    updateSteps();
  }

  /* ───────── Lightbox ───────── */
  var lightbox = document.getElementById("lightbox");
  var image = document.getElementById("lightboxImg");
  var caption = document.getElementById("lightboxCaption");
  var closeButton = document.getElementById("lightboxClose");
  var shots = [];
  var current = 0;
  var opener = null;
  // Everything behind the viewer, made inert while it is open.
  var page = Array.prototype.slice.call(document.querySelectorAll("body > header, body > main, body > footer"));

  function setInert(on) {
    page.forEach(function (region) { region.inert = on; });
  }

  function show(index) {
    current = (index + shots.length) % shots.length;
    var figure = shots[current];
    var img = figure.querySelector("img");
    image.src = img.currentSrc || img.src;
    image.alt = img.alt;
    caption.textContent = figure.querySelector("figcaption").textContent;
  }

  function open(figure) {
    shots = Array.prototype.slice.call(activePanel().querySelectorAll(".shot"));
    opener = document.activeElement;
    show(shots.indexOf(figure));
    lightbox.hidden = false;
    setInert(true);
    document.body.style.overflow = "hidden";
    closeButton.focus();
  }

  function close() {
    lightbox.hidden = true;
    setInert(false);
    document.body.style.overflow = "";
    if (opener) opener.focus();
  }

  if (lightbox) {
    Array.prototype.forEach.call(document.querySelectorAll(".shot__open"), function (button) {
      button.addEventListener("click", function () { open(button.closest(".shot")); });
    });
    closeButton.addEventListener("click", close);
    document.getElementById("lightboxPrev").addEventListener("click", function () { show(current - 1); });
    document.getElementById("lightboxNext").addEventListener("click", function () { show(current + 1); });
    lightbox.addEventListener("click", function (e) {
      if (e.target === lightbox) close();
    });
    // A sideways swipe steps through the screens, as the arrows do.
    var touchX = null;
    lightbox.addEventListener("touchstart", function (e) {
      touchX = e.touches.length === 1 ? e.touches[0].clientX : null;
    }, { passive: true });
    lightbox.addEventListener("touchend", function (e) {
      if (touchX === null) return;
      var dx = e.changedTouches[0].clientX - touchX;
      touchX = null;
      if (Math.abs(dx) > 48) show(current + (dx < 0 ? 1 : -1));
    });
    document.addEventListener("keydown", function (e) {
      if (lightbox.hidden) return;
      if (e.key === "Escape") close();
      else if (e.key === "ArrowLeft") show(current - 1);
      else if (e.key === "ArrowRight") show(current + 1);
      else if (e.key === "Tab") {
        // Keep focus inside the dialog while it is open.
        var controls = lightbox.querySelectorAll("button");
        var first = controls[0];
        var last = controls[controls.length - 1];
        if (e.shiftKey && document.activeElement === first) { last.focus(); e.preventDefault(); }
        else if (!e.shiftKey && document.activeElement === last) { first.focus(); e.preventDefault(); }
      }
    });
  }
})();
