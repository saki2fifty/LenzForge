import cv2

def overlay_landmarks(frame, landmark_data):
    """Overlay landmarks on frame"""
    if not landmark_data:
        return frame

    h, w = frame.shape[:2]

    # Draw face mesh landmarks
    if 'face' in landmark_data and landmark_data['face']:
        for lm in landmark_data['face']:
            x = int(lm['x'] * w)
            y = int(lm['y'] * h)

            # Color based on confidence
            confidence = lm.get('confidence', 1.0)
            if confidence > 0.8:
                color = (0, 255, 0)  # Green for high confidence
            elif confidence > 0.5:
                color = (0, 255, 255)  # Yellow for medium
            else:
                color = (0, 0, 255)  # Red for low

            cv2.circle(frame, (x, y), 1, color, -1)

    # Draw iris landmarks
    if 'iris' in landmark_data:
        for eye_name in ['left', 'right']:
            if eye_name in landmark_data['iris']:
                iris = landmark_data['iris'][eye_name]
                if iris:
                    for lm in iris:
                        x = int(lm['x'] * w)
                        y = int(lm['y'] * h)
                        cv2.circle(frame, (x, y), 2, (255, 0, 255), -1)  # Magenta

    # Draw hand landmarks
    if 'hands' in landmark_data:
        for hand_name in ['left', 'right']:
            if hand_name in landmark_data['hands']:
                hand = landmark_data['hands'][hand_name]
                if hand:
                    # Draw connections
                    connections = get_hand_connections()
                    for start_idx, end_idx in connections:
                        if start_idx < len(hand) and end_idx < len(hand):
                            start = hand[start_idx]
                            end = hand[end_idx]
                            x1, y1 = int(start['x'] * w), int(start['y'] * h)
                            x2, y2 = int(end['x'] * w), int(end['y'] * h)
                            cv2.line(frame, (x1, y1), (x2, y2), (0, 255, 255), 2)

                    # Draw landmarks
                    for lm in hand:
                        x = int(lm['x'] * w)
                        y = int(lm['y'] * h)
                        cv2.circle(frame, (x, y), 3, (255, 255, 0), -1)

    # Draw pose landmarks
    if 'pose' in landmark_data and landmark_data['pose']:
        # Draw connections
        connections = get_pose_connections()
        for start_idx, end_idx in connections:
            if start_idx < len(landmark_data['pose']) and end_idx < len(landmark_data['pose']):
                start = landmark_data['pose'][start_idx]
                end = landmark_data['pose'][end_idx]

                # Only draw if both visible
                if start.get('visibility', 0) > 0.5 and end.get('visibility', 0) > 0.5:
                    x1, y1 = int(start['x'] * w), int(start['y'] * h)
                    x2, y2 = int(end['x'] * w), int(end['y'] * h)
                    cv2.line(frame, (x1, y1), (x2, y2), (255, 0, 0), 2)

        # Draw landmarks
        for lm in landmark_data['pose']:
            if lm.get('visibility', 0) > 0.5:
                x = int(lm['x'] * w)
                y = int(lm['y'] * h)
                cv2.circle(frame, (x, y), 3, (0, 165, 255), -1)  # Orange

    return frame

def get_hand_connections():
    """Get hand landmark connections for drawing skeleton"""
    return [
        # Thumb
        (0, 1), (1, 2), (2, 3), (3, 4),
        # Index finger
        (0, 5), (5, 6), (6, 7), (7, 8),
        # Middle finger
        (0, 9), (9, 10), (10, 11), (11, 12),
        # Ring finger
        (0, 13), (13, 14), (14, 15), (15, 16),
        # Pinky
        (0, 17), (17, 18), (18, 19), (19, 20),
        # Palm
        (5, 9), (9, 13), (13, 17)
    ]

def get_pose_connections():
    """Get pose landmark connections for drawing skeleton"""
    return [
        # Face
        (0, 1), (1, 2), (2, 3), (3, 7),
        (0, 4), (4, 5), (5, 6), (6, 8),
        # Torso
        (9, 10),
        (11, 12), (11, 13), (13, 15), (15, 17), (15, 19), (15, 21), (17, 19),
        (12, 14), (14, 16), (16, 18), (16, 20), (16, 22), (18, 20),
        (11, 23), (12, 24), (23, 24),
        # Legs
        (23, 25), (25, 27), (27, 29), (27, 31), (29, 31),
        (24, 26), (26, 28), (28, 30), (28, 32), (30, 32)
    ]
