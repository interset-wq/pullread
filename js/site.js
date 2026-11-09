(() => {
  const body = document.body;
  const navToggle = document.querySelector("[data-nav-toggle]");
  const navLinks = document.querySelectorAll("#site-nav a");

  const setNav = (open) => {
    body.classList.toggle("nav-open", open);
    if (navToggle) {
      navToggle.setAttribute("aria-expanded", String(open));
      navToggle.setAttribute("aria-label", open ? "关闭导航菜单" : "打开导航菜单");
    }
  };

  if (navToggle) {
    navToggle.addEventListener("click", () => {
      setNav(!body.classList.contains("nav-open"));
    });
  }

  navLinks.forEach((link) => {
    link.addEventListener("click", () => setNav(false));
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      setNav(false);
    }
  });

  window.addEventListener("resize", () => {
    if (window.innerWidth > 760) {
      setNav(false);
    }
  });

  const copyBtn = document.querySelector("[data-copy-target]");
  if (copyBtn) {
    copyBtn.addEventListener("click", async () => {
      const target = document.querySelector(copyBtn.dataset.copyTarget);
      if (!target) return;

      const text = target.innerText.trim();
      try {
        await navigator.clipboard.writeText(text);
      } catch {
        const textarea = document.createElement("textarea");
        textarea.value = text;
        textarea.style.position = "fixed";
        textarea.style.opacity = "0";
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand("copy");
        textarea.remove();
      }

      copyBtn.textContent = "已复制";
      copyBtn.disabled = true;
      window.setTimeout(() => {
        copyBtn.textContent = "复制";
        copyBtn.disabled = false;
      }, 1600);
    });
  }

  const video = document.querySelector("[data-teaser-video]");
  const playBtn = document.querySelector("[data-play]");
  if (video && playBtn) {
    playBtn.addEventListener("click", () => {
      video.play();
    });

    video.addEventListener("play", () => {
      playBtn.hidden = true;
    });

    video.addEventListener("pause", () => {
      playBtn.hidden = false;
    });

    video.addEventListener("ended", () => {
      playBtn.hidden = false;
    });
  }

  const reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && reveals.length) {
    const observer = new IntersectionObserver(
      (entries, io) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );

    reveals.forEach((element) => observer.observe(element));
  } else {
    reveals.forEach((element) => element.classList.add("is-visible"));
  }
})();
