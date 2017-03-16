(in-package :spinneret)

(progn
  (deftype elastic-newline ()
    '(eql #1=:elastic-newline))
  (serapeum:defconst elastic-newline #1#))

(defclass html-stream (fundamental-character-input-stream)
  ((col :type (integer 0 *) :initform 0)
   (line :type (integer 0 *) :initform 0)
   (last-char :type (or character elastic-newline)
              ;; The last char defaults to newline to get reasonable
              ;; behavior from fresh-line.
              :initform #\Newline
              :accessor .last-char)
   (base-stream :type stream
                :initarg :base-stream)))

(defun make-html-stream (base-stream)
  (make-instance 'html-stream
                 :base-stream base-stream))

(serapeum:defmethods html-stream (s col line last-char base-stream)
  (:method stream-line-column (s)
    col)

  (:method stream-start-line-p (s)
    (= col 0))

  (:method stream-write-char (s char)
    (when (eql last-char elastic-newline)
      (unless (eql char #\Newline)
        (write-char #\Newline base-stream)
        (incf line)
        (setf col 0)))
    (when (eql char #\Newline)
      (incf line)
      (setf col 0))
    (write-char char base-stream)
    (setf last-char char)
    char)

  (:method stream-write-string (s string &optional (start 0) end)
    (let ((end (or end (length string)))
          (start (or start 0)))
      (declare (type array-index start end))
      (nlet rec ((start start))
        (let ((nl (or (position #\Newline string :start start :end end)
                      end)))
          (write-string string base-stream :start start :end nl)
          (when (> (- nl start) 0)
            (when (eql last-char elastic-newline)
              (incf line)
              (setf col 0)
              (terpri base-stream))
            (let ((end-char (aref string (1- nl))))
              (setf last-char end-char)))
          (incf col (- nl start))
          (unless (= nl end)
            (incf line)
            (setf col 0)
            (terpri base-stream)
            (rec (1+ nl))))))
    string)

  (:method stream-terpri (s)
    (incf line)
    (setf col 0)
    (setf last-char #\Newline)
    (terpri base-stream))

  (:method stream-fresh-line (s)
    (unless (eql last-char #\Newline)
      (terpri s)))

  (:method stream-finish-output (s)
    (finish-output base-stream))

  (:method stream-force-output (s)
    (force-output base-stream))

  (:method stream-advance-to-column (s c)
    (when (< col c)
      (loop repeat (- c col) do
        (write-char #\Space s)))
    t)

  (:method elastic-newline (s)
    (setf last-char elastic-newline)))
