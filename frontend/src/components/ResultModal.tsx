import './ResultModal.css';

interface ResultModalProps {
  isCorrect: boolean;
  isReal: boolean;
}

export const ResultModal = ({ isCorrect, isReal }: ResultModalProps) => {
  const getMessage = () => {
    if (isCorrect) {
      return isReal ? 'Да, это новость правда!' : 'Да, это фейк!';
    } else {
      return isReal ? 'Нет, это новость правда!' : 'Нет, это фейк!';
    }
  };

  return (
    <div className="result-modal">
      <div className={`result-modal__banner`}>
        {getMessage()}
      </div>
    </div>
  );
};
