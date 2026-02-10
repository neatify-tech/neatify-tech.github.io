const downloads = document.querySelectorAll("[data-download]");
async function loadDownloads() {
	try {
		const response = await fetch("downloads/latest.json", { cache: "no-store" });
		if (!response.ok) {
			throw new Error("Missing latest.json");
		}
		const payload = await response.json();
		const assets = payload.assets || [];
		downloads.forEach(
			(button) => {
				const card = button.closest("[data-os]");
				if (!card) {
					return;
				}
				const os = card.dataset.os;
				const arch = card.dataset.arch;
				const match = assets.find(
					(asset) => asset.os === os && asset.arch === arch
				);
				if (match) {
					button.textContent = `Download v${payload.version}`;
					button.href = `downloads/${match.file}`;
				}
				else {
					button.textContent = "Unavailable";
					button.classList.add("ghost");
					button.removeAttribute("href");
				}
			}
		);
	}
	catch (error) {
		downloads.forEach(
			(button) => {
				button.textContent = "See releases";
				button.href = "https://github.com/neatify-tech/neatify/releases";
			}
		);
	}
}
loadDownloads();
