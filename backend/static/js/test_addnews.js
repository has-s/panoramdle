const authForm = document.getElementById('auth-form');
const newsForm = document.getElementById('news-form');
const authResult = document.getElementById('auth-result');
const previewContainer = document.getElementById('preview');
const afterSubmit = document.getElementById('after-submit');

const previewHeadline = document.getElementById('preview-headline');
const previewText = document.getElementById('preview-text');
const previewMedia = document.getElementById('preview-media');
const previewIsReal = document.getElementById('preview-is-real');
const previewSource = document.getElementById('preview-source');

// Auth
authForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(authForm);
    const resp = await fetch('/api/auth', { method: 'POST', body: formData });
    const data = await resp.json();
    if (data.ok) {
        authForm.style.display = 'none';
        newsForm.style.display = 'block';
        const authHeader = document.querySelector('.column h2');
        if (authHeader) authHeader.textContent = 'Добавить новость';
    } else {
        authResult.textContent = 'Неверный пароль';
    }
});

// Preview
newsForm.addEventListener('input', () => {
    const f = newsForm;

    // undate media
    previewHeadline.textContent = f.headline.value;
    previewText.textContent = f.text.value;
    previewIsReal.textContent = f.is_real.checked ? "(REAL)" : "(FAKE)";
    document.getElementById('preview-source').textContent = f.source_name.value;

    if ((f.format.value === 'img' || f.format.value === 'img_txt') && f.media_url.value) {
        previewMedia.src = f.media_url.value;
        previewMedia.style.display = "block";
    } else {
        previewMedia.style.display = "none";
    }

    if (f.format.value === 'txt' || f.format.value === 'img_txt') {
        previewText.style.display = "block";
    } else {
        previewText.style.display = "none";
    }

    // show/hide preview
    const hasContent = f.headline.value || f.text.value || f.media_url.value || f.source_name.value;
    document.getElementById('preview').style.display = hasContent ? "flex" : "none";
});

// send news
newsForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const f = newsForm;
    const headlineFilled = f.headline.value.trim() !== "";
    const sourceFilled = f.source_name.value.trim() !== "";
    const format = f.format.value;
    const textFilled = f.text.value.trim() !== "";
    const mediaFilled = f.media_url.value.trim() !== "";

    // req. fields
    let valid = headlineFilled && sourceFilled;
    if (format === "txt") valid = valid && textFilled;
    if (format === "img") valid = valid && mediaFilled;
    if (format === "img_txt") valid = valid && textFilled && mediaFilled;

    if (!valid) {
        alert("Заполните все обязательные поля для выбранного формата.");
        return;
    }

    const formData = new FormData(newsForm);
    const resp = await fetch('/api/addnews', { method: 'POST', body: formData });
    const data = await resp.json();

    if (data.ok) {

        newsForm.style.display = 'none';
        previewContainer.style.display = 'none';
        afterSubmit.style.display = 'block';
    } else {
        alert("Ошибка при добавлении новости");
    }
});

// send button
document.getElementById('add-another').addEventListener('click', () => {
    newsForm.reset();
    newsForm.style.display = 'block';
    previewContainer.style.display = 'none';
    afterSubmit.style.display = 'none';
});

document.getElementById('go-quiz').addEventListener('click', () => {
    window.location.href = '/';
});