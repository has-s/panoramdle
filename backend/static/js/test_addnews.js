const authForm = document.getElementById("auth-form");
const newsForm = document.getElementById("news-form");
const authResult = document.getElementById("auth-result");
const title = document.getElementById("title");

const savedPassword = document.getElementById("saved-password");
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

/* --- auth --- */
authForm.addEventListener("submit", async e => {
    e.preventDefault();
    const fd = new FormData(authForm);
    const resp = await fetch("/api/auth", { method: "POST", body: fd });
    const data = await resp.json();
    if (data.ok) {
        const password = fd.get("password");
        savedPassword.value = password;
        authForm.style.display = "none";
        newsForm.style.display = "block";
        title.textContent = "Добавить новость";
    } else {
        authResult.textContent = "Неверный пароль";
    }
});

/* --- checkbox --- */
isRealCheckbox.addEventListener("change", () => {
    isRealHidden.value = isRealCheckbox.checked ? "true" : "false";
});

/* --- preview --- */
newsForm.addEventListener("input", () => {
    const f = newsForm;
    previewHeadline.textContent = f.headline.value;
    previewText.textContent = f.text.value;
    previewIsReal.textContent = f.is_real.value === "true" ? "(REAL)" : "(FAKE)";
    previewSource.textContent = f.source_name.value;

    if ((f.format.value === "img" || f.format.value === "img_txt") && f.media_url.value) {
        previewMedia.src = f.media_url.value;
        previewMedia.style.display = "block";
    } else {
        previewMedia.style.display = "none";
    }

    previewText.style.display = (f.format.value === "txt" || f.format.value === "img_txt") ? "block" : "none";

    const hasContent = f.headline.value || f.text.value || f.media_url.value || f.source_name.value;
    previewContainer.style.display = hasContent ? "block" : "none";
});

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
    const resp = await fetch("/api/addnews", { method: "POST", body: fd });
    const data = await resp.json();

    if (resp.ok && data.ok) {
        newsForm.reset();
        previewContainer.style.display = "none";
        isRealHidden.value = "false";
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
});