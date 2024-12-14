import { useEffect, useState } from 'react';

export const useKeyPress = (targetKeys: string[]) => {
  const [isPressed, setIsPressed] = useState(false);

  useEffect(() => {
    const downHandler = (event: KeyboardEvent) => {
      if (targetKeys.includes(event.key)) {
        setIsPressed(true);
      }
    };

    const upHandler = (event: KeyboardEvent) => {
      if (targetKeys.includes(event.key)) {
        setIsPressed(false);
      }
    };

    window.addEventListener('keydown', downHandler);
    window.addEventListener('keyup', upHandler);

    return () => {
      window.removeEventListener('keydown', downHandler);
      window.removeEventListener('keyup', upHandler);
    };
  }, [targetKeys]);

  return isPressed;
};
