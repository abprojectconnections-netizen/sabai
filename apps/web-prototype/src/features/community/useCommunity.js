import { useState, useRef, useEffect } from 'react';
import { GROUPS, MEMBERS } from '../../data/catalog';
import { ME_ID, POST_MAX, POST_MIN } from './constants';

export function useCommunity({ showToast, pushNotification, onSaveTrip, seed }) {
  const [posts, setPosts] = useState(seed.posts);
  const [comments, setComments] = useState(seed.comments);
  const [liked, setLiked] = useState([]);
  const [saved, setSaved] = useState([]);
  const [likedComments, setLikedComments] = useState([]);
  const [following, setFollowing] = useState(['m1']);
  const [joined, setJoined] = useState(['g1']);
  const [hidden, setHidden] = useState([]);
  const [copiedTrips, setCopiedTrips] = useState([]);
  const [ui, setUi] = useState({ tab: 'feed', feedMode: 'all', dest: 'ทั้งหมด', qaFilter: 'all' });
  const [selected, setSelected] = useState({ postId: null, memberId: null, groupId: null });
  const [composer, setComposer] = useState({ type: 'story', destination: '', text: '', groupId: null });
  const [sheet, setSheet] = useState(null);
  const timers = useRef([]);
  useEffect(() => () => timers.current.forEach(clearTimeout), []);

  const toggle = (setter, id) => setter((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));

  const memberOf = (id) => MEMBERS.find((m) => m.id === id) || MEMBERS[0];
  const commentsOf = (postId) => comments[postId] || [];
  const visiblePosts = posts.filter((p) => !hidden.includes(p.id));
  const postById = (id) => posts.find((p) => p.id === id) || null;
  const likeCount = (post) => post.likes + (liked.includes(post.id) ? 1 : 0);
  const followerCount = (m) => m.followers + (following.includes(m.id) ? 1 : 0);
  const memberCount = (g) => g.members + (joined.includes(g.id) ? 1 : 0);

  const toggleLike = (id) => toggle(setLiked, id);
  const toggleSave = (id) => {
    const wasSaved = saved.includes(id);
    toggle(setSaved, id);
    showToast(wasSaved ? 'เลิกบันทึกโพสต์แล้ว' : 'บันทึกโพสต์แล้ว');
  };
  const toggleCommentLike = (id) => toggle(setLikedComments, id);
  const toggleFollow = (id) => {
    const was = following.includes(id);
    toggle(setFollowing, id);
    showToast(was ? `เลิกติดตาม ${memberOf(id).name} แล้ว` : `ติดตาม ${memberOf(id).name} แล้ว`);
  };
  const toggleJoin = (id) => {
    const was = joined.includes(id);
    toggle(setJoined, id);
    const g = GROUPS.find((x) => x.id === id);
    showToast(was ? `ออกจากกลุ่ม "${g.name}" แล้ว` : `เข้าร่วมกลุ่ม "${g.name}" แล้ว`);
  };

  const addComment = (postId, text) => {
    const clean = text.trim();
    if (!clean) return;
    setComments((prev) => ({ ...prev, [postId]: [...(prev[postId] || []), { id: `c${Date.now()}`, authorId: ME_ID, text: clean, time: 'เมื่อสักครู่', likes: 0 }] }));
  };
  const markBest = (postId, commentId) => {
    setComments((prev) => ({ ...prev, [postId]: (prev[postId] || []).map((c) => ({ ...c, best: c.id === commentId ? !c.best : false })) }));
    showToast('อัปเดตคำตอบที่ดีที่สุดแล้ว');
  };

  const startPost = ({ type = 'story', groupId = null } = {}) => {
    const g = GROUPS.find((x) => x.id === groupId);
    setComposer({ type, destination: (g && g.destination) || '', text: '', groupId });
  };
  const updateComposer = (patch) => setComposer((prev) => ({ ...prev, ...patch }));
  const createPost = () => {
    const text = composer.text.trim();
    if (text.length < POST_MIN || text.length > POST_MAX || !composer.destination) return null;
    const id = `p${Date.now()}`;
    setPosts((prev) => [{ id, authorId: ME_ID, type: composer.type, destination: composer.destination, groupId: composer.groupId, time: 'เมื่อสักครู่', likes: 0, text }, ...prev]);
    setUi((prev) => ({ ...prev, tab: composer.type === 'question' ? 'qa' : 'feed', feedMode: 'all', dest: 'ทั้งหมด' }));
    showToast('โพสต์ของคุณเผยแพร่แล้ว');
    // จำลองปฏิกิริยาจากสมาชิกคนอื่นเพื่อแสดงการแจ้งเตือนของชุมชน
    timers.current.push(setTimeout(() => {
      setPosts((prev) => prev.map((p) => (p.id === id ? { ...p, likes: p.likes + 3 } : p)));
      pushNotification('community', 'มีคนถูกใจโพสต์ของคุณ', 'มะลิ ทองดี และอีก 2 คนถูกใจโพสต์ของคุณในชุมชน');
    }, 4000));
    setComposer({ type: 'story', destination: '', text: '', groupId: null });
    return id;
  };
  const deletePost = (id) => {
    setPosts((prev) => prev.filter((p) => p.id !== id));
    setSaved((prev) => prev.filter((x) => x !== id));
    showToast('ลบโพสต์แล้ว');
  };
  const reportPost = (id) => {
    setHidden((prev) => [...prev, id]);
    showToast('ส่งรายงานแล้ว ขอบคุณที่ช่วยดูแลชุมชน');
  };
  const hidePost = (id) => {
    setHidden((prev) => [...prev, id]);
    showToast('ซ่อนโพสต์นี้แล้ว');
  };
  const sharePost = async (id) => {
    try {
      await navigator.clipboard.writeText(`https://sabai.example/community/${id}`);
      showToast('คัดลอกลิงก์โพสต์แล้ว');
    } catch {
      showToast('คัดลอกลิงก์ไม่สำเร็จ ลองอีกครั้ง');
    }
  };
  const copyTrip = (post) => {
    if (!post.sharedTrip) return;
    if (copiedTrips.includes(post.id)) { showToast('คุณบันทึกทริปนี้ไว้แล้ว'); return; }
    onSaveTrip(post);
    setCopiedTrips((prev) => [...prev, post.id]);
    showToast('บันทึกทริปแล้ว ดูได้ที่แท็บทริป');
  };

  return {
    posts, visiblePosts, comments, liked, saved, likedComments, following, joined, copiedTrips, ui, selected, composer, sheet,
    memberOf, commentsOf, postById, likeCount, followerCount, memberCount,
    setUi: (patch) => setUi((prev) => ({ ...prev, ...patch })),
    selectPost: (postId) => setSelected((prev) => ({ ...prev, postId })),
    selectMember: (memberId) => setSelected((prev) => ({ ...prev, memberId })),
    selectGroup: (groupId) => setSelected((prev) => ({ ...prev, groupId })),
    openSheet: setSheet, closeSheet: () => setSheet(null),
    toggleLike, toggleSave, toggleCommentLike, toggleFollow, toggleJoin,
    addComment, markBest, startPost, updateComposer, createPost, deletePost, reportPost, hidePost, sharePost, copyTrip,
  };
}
