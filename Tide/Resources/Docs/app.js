const root = document.documentElement;
const themeButton = document.querySelector("#theme");
const storedTheme = localStorage.getItem("tide-docs-theme");

if (storedTheme) {
  root.dataset.theme = storedTheme;
}

themeButton?.addEventListener("click", () => {
  const next = root.dataset.theme === "dark" ? "light" : "dark";
  root.dataset.theme = next;
  localStorage.setItem("tide-docs-theme", next);
});

document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    const target = document.getElementById(button.dataset.copy);
    if (!target) return;
    try {
      await navigator.clipboard.writeText(target.innerText);
      const previous = button.textContent;
      button.textContent = "Copied";
      setTimeout(() => { button.textContent = previous; }, 1200);
    } catch {
      button.textContent = "Select code";
    }
  });
});

const sections = [...document.querySelectorAll("article section")];
const links = [...document.querySelectorAll(".sidebar a")];

const observer = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (!entry.isIntersecting) return;
    links.forEach((link) => {
      const active = link.getAttribute("href") === `#${entry.target.id}`;
      link.style.color = active ? "var(--ink)" : "";
      link.style.fontWeight = active ? "750" : "";
    });
  });
}, { rootMargin: "-20% 0px -70% 0px" });

sections.forEach((section) => observer.observe(section));
