(() => {
  const dialog = document.querySelector('.map-dialog');
  const viewport = document.querySelector('.map-viewport');
  const image = viewport.querySelector('img');
  let scale = 1, x = 0, y = 0, drag = null;

  function render() { image.style.transform = `translate(${x}px, ${y}px) scale(${scale})`; }
  function reset() { scale = 1; x = 0; y = 0; render(); }
  function zoom(next, originX = viewport.clientWidth / 2, originY = viewport.clientHeight / 2) {
    const value = Math.min(6, Math.max(1, next));
    const ratio = value / scale;
    x = originX - (originX - x) * ratio; y = originY - (originY - y) * ratio;
    scale = value; render();
  }
  document.querySelectorAll('[data-open-map]').forEach(button => button.addEventListener('click', () => { dialog.showModal(); reset(); }));
  document.querySelector('[data-close-map]').addEventListener('click', () => dialog.close());
  document.querySelector('[data-zoom-in]').addEventListener('click', () => zoom(scale * 1.35));
  document.querySelector('[data-zoom-out]').addEventListener('click', () => zoom(scale / 1.35));
  document.querySelector('[data-zoom-reset]').addEventListener('click', reset);
  viewport.addEventListener('wheel', event => { event.preventDefault(); const box = viewport.getBoundingClientRect(); zoom(scale * (event.deltaY < 0 ? 1.15 : 1 / 1.15), event.clientX - box.left, event.clientY - box.top); }, { passive: false });
  viewport.addEventListener('pointerdown', event => { drag = { x: event.clientX, y: event.clientY, imageX: x, imageY: y }; viewport.setPointerCapture(event.pointerId); });
  viewport.addEventListener('pointermove', event => { if (!drag) return; x = drag.imageX + event.clientX - drag.x; y = drag.imageY + event.clientY - drag.y; render(); });
  viewport.addEventListener('pointerup', () => { drag = null; });
})();
