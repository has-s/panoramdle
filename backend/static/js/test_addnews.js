const newsForm = document.getElementById("news-form");
const isRealCheckbox = document.getElementById("is_real_checkbox");
const isRealHidden = document.getElementById("is_real_hidden");

const previewContainer = document.getElementById("preview");
const previewHeadline = document.getElementById("preview-headline");
const previewText = document.getElementById("preview-text");
const previewMedia = document.getElementById("preview-media");
const previewIsReal = document.getElementById("preview-is-real");
const previewSource = document.getElementById("preview-source");

const afterSubmit = document.getElementById("after-submit");
const addAnother = document.getElementById("add-another");

/* --- checkbox --- */
isRealCheckbox.addEventListener("change", () => {
    isRealHidden.value = isRealCheckbox.checked ? "true" : "false";
    updatePreview();
});

/* --- preview update function --- */
function updatePreview() {
    const f = newsForm;
    previewHeadline.textContent = f.headline.value || "Заголовок новости";
    previewText.textContent = f.text.value || "Текст новости...";

    previewIsReal.textContent = f.is_real.value === "true" ? "(REAL)" : "(FAKE)";

    previewSource.textContent = f.source_name.value || "Источник";

    if ((f.format.value === "img" || f.format.value === "img_txt") && f.media_url.value) {
        previewMedia.src = f.media_url.value;
        previewMedia.style.display = "block";
    } else {
        previewMedia.style.display = "none";
    }

    previewText.style.display = (f.format.value === "txt" || f.format.value === "img_txt") ? "block" : "none";

    const hasContent = f.headline.value || f.text.value || f.media_url.value || f.source_name.value;
    previewContainer.style.display = hasContent ? "block" : "none";
}

/* --- preview on input --- */
newsForm.addEventListener("input", updatePreview);

/* --- send news --- */
newsForm.addEventListener("submit", async e => {
    e.preventDefault();
    const f = newsForm;
    const headlineFilled = f.headline.value.trim() !== "";
    const sourceFilled = f.source_name.value.trim() !== "";
    const format = f.format.value;
    const textFilled = f.text.value.trim() !== "";
    const mediaFilled = f.media_url.value.trim() !== "";

    let valid = headlineFilled && sourceFilled;
    if (format === "txt") valid = valid && textFilled;
    if (format === "img") valid = valid && mediaFilled;
    if (format === "img_txt") valid = valid && textFilled && mediaFilled;

    if (!valid) {
        alert("Заполните все обязательные поля для выбранного формата.");
        return;
    }

    const fd = new FormData(newsForm);
    const resp = await fetch("/api/news/add", { method: "POST", body: fd });
    const data = await resp.json();

    if (resp.ok && data.ok) {
        newsForm.reset();
        previewContainer.style.display = "none";
        isRealHidden.value = "false";
        newsForm.style.display = "none";
        afterSubmit.style.display = "block";
    } else {
        alert("Ошибка при добавлении новости: " + JSON.stringify(data));
    }
});

/* --- add another --- */
addAnother.addEventListener("click", () => {
    newsForm.style.display = "block";
    afterSubmit.style.display = "none";
    previewContainer.style.display = "none";
    newsForm.reset();
    isRealHidden.value = "false";
});