import './ResultModal.css';

interface ResultModalProps {
  isCorrect: boolean;
  isReal: boolean;
}

export const ResultModal = ({ isCorrect, isReal }: ResultModalProps) => {
  const getMessage = () => {
    if (isCorrect) {
      return isReal ? 'Да, эта новость правда!' : 'Да, эта новость фейк!';
    } else {
      return isReal ? 'Нет, эта новость правда!' : 'Нет, эта новость фейк!';
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
