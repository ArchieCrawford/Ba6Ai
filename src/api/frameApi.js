export const frameApi = {
  validateAction: async (messageBytes) => {
    try {
      const response = await fetch('/.netlify/functions/neynar-validate', {
        method: 'POST',
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json'
        },
        body: JSON.stringify({ message_bytes_in_hex: messageBytes })
      });
      return await response.json();
    } catch (err) {
      console.error('Frame validation failed:', err);
      return { valid: false };
    }
  },

  getNextFrame: (currentState, buttonIndex, fid) => {
    if (currentState === 'home') {
      if (buttonIndex === 1) return frameApi.getChatFrame(fid);
      if (buttonIndex === 2) return frameApi.getImageFrame(fid);
      if (buttonIndex === 3) return frameApi.getSigninFrame(fid);
    }

    return frameApi.getHomeFrame();
  },

  getHomeFrame: () => ({
    image: `https://placehold.co/1200x630/000000/FFFFFF?text=BA6+AI+-+Home`,
    buttons: ['Chat', 'Image', 'Sign In'],
    state: 'home'
  }),

  getChatFrame: (fid) => ({
    image: `https://placehold.co/1200x630/000000/FFFFFF?text=BA6+AI+-+Chat+FID:${fid}`,
    buttons: ['Open App', 'Back'],
    action: 'link',
    target: `${window.location.origin}/app/chat`,
    state: 'chat'
  }),

  getImageFrame: (fid) => ({
    image: `https://placehold.co/1200x630/000000/FFFFFF?text=BA6+AI+-+Image+Gen+FID:${fid}`,
    buttons: ['Open App', 'Back'],
    action: 'link',
    target: `${window.location.origin}/app/images`,
    state: 'image'
  }),

  getSigninFrame: (fid) => ({
    image: `https://placehold.co/1200x630/000000/FFFFFF?text=BA6+AI+-+Sign+In+FID:${fid}`,
    buttons: ['Open BA6 AI'],
    action: 'link',
    target: `${window.location.origin}/app`,
    state: 'signin'
  })
};
