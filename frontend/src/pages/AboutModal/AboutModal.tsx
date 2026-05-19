import './AboutModal.css';

interface AboutModalProps {
  onClose: () => void;
}

export const AboutModal = ({ onClose }: AboutModalProps) => {
  return (
    <div className="about-overlay" onClick={onClose}>
      <div className="about-modal" onClick={(e) => e.stopPropagation()}>
        <button className="about-modal__close" onClick={onClose}>✕</button>

        <h2 className="about-modal__title">О проекте</h2>

        <div className="about-modal__section">
          <p className="about-modal__text">
            Все новости на сайте отобраны вручную — это работа нашей <em>редакции</em>.
            Мы не проверяем публикации на достоверность: одни взяты из СМИ, пабликов
            и телеграм-каналов, другие придуманы с нуля командой нашего сайта
            (иногда мы их внаглую крадём из Пёздузы и Панорамы).
          </p>
          <p className="about-modal__text">
            Есть пожелания или хотите предложить новость? Форма ждёт.
          </p>
        </div>

        <div className="about-modal__divider" />

        <div className="about-modal__section">
          <h3 className="about-modal__section-title">Команда</h3>
          <div className="about-modal__team">
            <div className="about-modal__team-col">
              <div className="about-modal__team-role">Программисты</div>
              <ul className="about-modal__team-list">
                <li>имя 1 (ака имя 2)</li>
                <li><a href="#" className="about-modal__link">имя 3</a></li>
              </ul>
            </div>
            <div className="about-modal__team-col">
              <div className="about-modal__team-role">Редакция</div>
              <ul className="about-modal__team-list">
                <li>имя 4</li>
                <li>имя 5</li>
                <li><a href="#" className="about-modal__link">имя 3</a></li>
              </ul>
            </div>
          </div>
        </div>

        <div className="about-modal__divider" />

        <div className="about-modal__links">
          <a
            href="https://github.com/has-s/panoramdle/"
            target="_blank"
            rel="noopener noreferrer"
            className="about-modal__link-btn"
          >
            GitHub
          </a>
          <a
            href="#"
            target="_blank"
            rel="noopener noreferrer"
            className="about-modal__link-btn"
          >
            Жалобы и предложения
          </a>
          <a
            href="#"
            target="_blank"
            rel="noopener noreferrer"
            className="about-modal__link-btn"
          >
            Предложить новость
          </a>
        </div>

        <div className="about-modal__footer">
          Спасибо за визит!
        </div>
      </div>
    </div>
  );
};