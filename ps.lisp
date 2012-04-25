(in-package #:spinneret)

(defparameter *props*
  '("acceptCharset" "accessKey" "allowTransparency" "bgColor" "cellPadding"
    "cellSpacing" "className" "className" "colSpan" "style" "defaultChecked"
    "defaultSelected" "defaultValue" "htmlFor" "frameBorder" "hSpace" "htmlFor"
    "longDesc" "maxLength" "marginWidth" "marginHeight" "noResize" "noShade"
    "readOnly" "rowSpan" "tabIndex" "vAlign" "vSpace"))

(defparameter *ie-attr-props*
  '(("for"   . "htmlfor")
    ("class" . "classname")))

(define-ps-symbol-macro *html* (@ document spinneret))

(define-ps-symbol-macro *html-charset* (lisp *html-charset*))

(define-ps-symbol-macro *html-lang* (lisp *html-lang*))

(defpsmacro ch (&rest args)
  `(chain ,@args))

(defpsmacro with-html (&rest html-forms)
  `(progn
     (unless *html*
       (setf *html* (ch document (create-document-fragment))))
     ,@(with-standard-io-syntax
         (parse-html html-forms nil))
     (unless (@ *html* parent-node)
       (prog1 *html*
         (setf *html* nil)))))

(defpsmacro with-tag ((name &rest attributes) &body body)
  `(progn
     (setf *html*
           (ch *html*
               (append-child
                (ch document (create-element ,(string-downcase name))))))
     ,@(loop for (attr val . rest) on attributes by #'cddr
             collect (make-attr-setter (string-downcase attr) val))
     ,@(when body
         (loop for form in body
               if (and (consp form) (eql (car form) 'with-tag))
                 collect form
               else collect `(ch *html* (append-child
                                         (ch document
                                             (create-text-node
                                              (stringify ,form)))))))
     (setf *html* (@ *html* parent-node))
     nil))

(defun make-attr-setter (attr val)
  ;; Compatibility hacks from Laconic.js 0.2.2.
  (let ((attr (or (find
                   (or (cdr (assoc attr *ie-attr-props* :test #'string-equal))
                       attr)
                   *props* :test #'string-equal)
                  attr))
        (sval `(stringify ,val)))
    (cond
      ((event? attr)
       ;; Set events as properties, ensuring a href.
       `(setf (@ *html* ,attr) ,sval
              (@ *html* href)
              (or (@ *html* href) "#")))
      ;; Style requires special handling for IE.
      ((string-equal attr "style")
       `(if (@ *html* style set-attribute)
            (ch *html* style (set-attribute 'css-text ,sval))
            (ch *html* (set-attribute ,attr ,sval))))
      ((rassoc attr *ie-attr-props* :test #'string-equal)
       ;; Other special cases for IE.
       `(setf (@ *html* ,attr) ,sval))
      ((data-attr? attr)
       `(setf (@ *html* dataset ,(data-attr-prop attr)) ,sval))
      ((string-equal attr "attrs")
       (with-ps-gensyms (attrs attr)
         `(let ((,attrs ,val))
            (for-in (,attr ,attrs)
                    (ch *html*
                        (set-attribute ,attr
                                       (stringify (@ ,attrs ,attr))))))))
      (t `(ch *html* (set-attribute ,attr ,sval))))))

(defun event? (attr)
  (begins (string attr) "on"))

(defun data-attr? (attr)
  (begins (string attr) "data-"))

(defun data-attr-prop (attr)
  (subseq (string-downcase attr) 5))

(defun begins (seq pat &optional (start 0))
  (let ((mm (mismatch seq pat :start1 start
                              :test #'char-equal)))
    (if mm
        (= mm (length pat))
        t)))

(defpsmacro comment (text safe?)
  (declare (ignore safe?))
  `(stringify
    ,(ps::concat-constant-strings
      (list "<!-- " text " -->"))))

(defpsmacro cdata (text safe?)
  (declare (ignore safe?))
  `(stringify
    ,(ps::concat-constant-strings
      (list *cdata-start* text *cdata-end*))))

(defpsmacro format-text (formatter &rest args)
  (let ((control-string
          (if (listp formatter)
              (second formatter)
              formatter)))
    (prog1 control-string
      (when args
        (cerror
         "Discard arguments and print \"~A\" literally."
         "Parenscript doesn't have FORMAT."
         control-string)))))

(defpsmacro class-union (&rest classes)
  `(stringify
    ,(ps::concat-constant-strings
      (intersperse " "
                   (remove-duplicates classes :test #'equal)))))

(defun intersperse (new-elt list)
  (cons (car list)
        (mapcan
         (lambda (elt)
           (list new-elt elt))
         (cdr list))))
