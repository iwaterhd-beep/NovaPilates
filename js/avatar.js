/** Foto de perfil: cámara, galería y subida a Storage. */
(function (global) {
  function applyNovaAvatar(el, url, letter) {
    if (!el) return;
    const initial = String(letter || '?').trim().charAt(0).toUpperCase() || '?';
    if (url) {
      el.style.backgroundImage = `url("${String(url).replace(/"/g, '')}")`;
      el.style.backgroundSize = 'cover';
      el.style.backgroundPosition = 'center';
      el.classList.add('has-photo');
      el.textContent = '';
    } else {
      el.style.backgroundImage = '';
      el.classList.remove('has-photo');
      el.textContent = initial;
    }
  }

  function novaCompressImage(file, maxEdge = 720) {
    return new Promise((resolve, reject) => {
      if (!file || (file.type && !file.type.startsWith('image/'))) {
        reject(new Error('Elige una imagen.'));
        return;
      }
      const img = new Image();
      const src = URL.createObjectURL(file);
      img.onload = () => {
        URL.revokeObjectURL(src);
        const scale = Math.min(1, maxEdge / Math.max(img.width, img.height));
        const w = Math.max(1, Math.round(img.width * scale));
        const h = Math.max(1, Math.round(img.height * scale));
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        canvas.getContext('2d').drawImage(img, 0, 0, w, h);
        canvas.toBlob((blob) => {
          if (!blob) {
            reject(new Error('No se pudo procesar la foto.'));
            return;
          }
          resolve(new File([blob], 'avatar.jpg', { type: 'image/jpeg' }));
        }, 'image/jpeg', 0.86);
      };
      img.onerror = () => {
        URL.revokeObjectURL(src);
        reject(new Error('No se pudo leer la imagen.'));
      };
      img.src = src;
    });
  }

  async function novaUploadAvatar(userId, file) {
    if (!userId) throw new Error('Falta el usuario.');
    if (!file) throw new Error('Elige o haz una foto.');
    if (file.size > 8 * 1024 * 1024) throw new Error('La foto supera 8 MB.');
    const packed = await novaCompressImage(file);
    const path = `${userId}/avatar.jpg`;
    const { error } = await novaSupabase.storage.from('avatares').upload(path, packed, {
      upsert: true,
      contentType: 'image/jpeg',
      cacheControl: '60'
    });
    if (error) throw error;
    const { data } = novaSupabase.storage.from('avatares').getPublicUrl(path);
    const url = `${data.publicUrl}?v=${Date.now()}`;
    const { error: upErr } = await novaSupabase
      .from('perfiles')
      .update({ avatar_url: url, updated_at: new Date().toISOString() })
      .eq('id', userId);
    if (upErr) throw upErr;
    return url;
  }

  function novaBindAvatarPicker(opts) {
    const { preview, fileInput, cameraInput, galleryInput, userId, letter, onUploaded, onPicked } = opts || {};
    const immediate = opts.immediate !== false;
    function letterNow() {
      return typeof letter === 'function' ? letter() : letter;
    }
    function showLocal(file) {
      if (!preview || !file) return;
      applyNovaAvatar(preview, URL.createObjectURL(file), letterNow());
    }
    async function handle(file) {
      if (!file) return;
      showLocal(file);
      if (typeof onPicked === 'function') onPicked(file);
      const id = typeof userId === 'function' ? userId() : userId;
      if (!immediate || !id) return;
      try {
        if (typeof showPageSpinner === 'function') showPageSpinner(true);
        const url = await novaUploadAvatar(id, file);
        applyNovaAvatar(preview, url, letterNow());
        if (typeof onUploaded === 'function') onUploaded(url);
        if (typeof showToast === 'function') showToast('Foto actualizada.', 'success');
        else if (typeof toast === 'function') toast('Foto actualizada.', 'success');
      } catch (e) {
        const msg = typeof friendlyError === 'function' ? friendlyError(e) : (e.message || 'No se pudo subir la foto.');
        if (typeof showToast === 'function') showToast(msg, 'error');
        else if (typeof toast === 'function') toast(msg, 'error');
      } finally {
        if (typeof showPageSpinner === 'function') showPageSpinner(false);
      }
    }
    function bindFile(input) {
      input?.addEventListener('change', (e) => {
        const f = e.target.files && e.target.files[0];
        e.target.value = '';
        handle(f);
      });
    }
    bindFile(fileInput);
    bindFile(cameraInput);
    bindFile(galleryInput);
  }

  function paintNovaSidebarAvatar(perfil) {
    applyNovaAvatar(
      document.getElementById('userAvatar'),
      perfil && perfil.avatar_url,
      (perfil && (perfil.nombre || perfil.email)) || 'C'
    );
  }

  global.applyNovaAvatar = applyNovaAvatar;
  global.paintNovaSidebarAvatar = paintNovaSidebarAvatar;
  global.novaCompressImage = novaCompressImage;
  global.novaUploadAvatar = novaUploadAvatar;
  global.novaBindAvatarPicker = novaBindAvatarPicker;
})(window);
