;;; -*- Mode: Lisp; Syntax: COMMON-LISP; Base: 10 -*-

;; cl-git is a Common Lisp interface to git repositories.
;; Copyright (C) 2011-2022 Russell Sim <russell.sim@gmail.com>
;; Copyright (C) 2014 Eric Timmons <etimmons@alum.mit.edu>
;;
;; This program is free software: you can redistribute it and/or
;; modify it under the terms of the GNU Lesser General Public License
;; as published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; Lesser General Public License for more details.
;;
;; You should have received a copy of the GNU Lesser General Public
;; License along with this program.  If not, see
;; <http://www.gnu.org/licenses/>.


(in-package #:cl-git)

(defconstant +git-clone-options-version+ 1)

(defcenum git-clone-local
  ;; will bypass the git-aware transport for local paths, but use
  ;; normal fetch for file:// URLs.
  (:auto)

  ;; Bypass git-aware transport for all URLs
  (:local)

  ;; Don't bypass git-aware transport
  (:no-local)

  ;; Bypass git-aware transport but don't use hardlinks
  (:local-no-links))

(defcstruct git-clone-options
  (version :unsigned-int)
  (checkout-options (:struct git-checkout-options))
  (fetch-options (:struct git-fetch-options))
  (bare :bool)
  (local git-clone-local)
  (checkout-branch :string)
  (repository-cb :pointer)
  (repository-cb-payload :pointer)
  (remote-cb :pointer)
  (remote-cb-payload :pointer))

(define-foreign-type clone-options ()
  ((fetch-options
    :initform (make-instance 'fetch-options)
    :accessor fetch-options))
  (:simple-parser %clone-options)
  (:actual-type :pointer))

(defcfun %git-clone-init-options
    %return-value
  (options :pointer)
  (version :uint))

(defcfun %git-clone
    %return-value
  (out :pointer)
  (url :string)
  (local-path :string)
  (options %clone-options))

(defmethod initialize-instance :after ((opts clone-options) &rest initargs &key credentials)
  (declare (ignore initargs))
  (when credentials
    (setf (remote-callbacks opts) (make-instance 'remote-callbacks :credentials credentials))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Translation Methods
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod translate-to-foreign (value (type clone-options))
  (let ((ptr (foreign-alloc '(:struct git-clone-options))))
    ;; Init the structure with default values.
    ;; TODO(RS) this struct is leaked here, there is no freeing of it
    (%git-clone-init-options ptr +git-clone-options-version+)
    (translate-into-foreign-memory value type ptr)))

(defmethod translate-into-foreign-memory ((value clone-options) (type clone-options) ptr)
  (with-foreign-slots (((:pointer fetch-options))
                       ptr (:struct git-clone-options))
    (translate-into-foreign-memory (fetch-options value) (fetch-options value) fetch-options)
    )
  ptr)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Highlevel Interface
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defgeneric clone-repository (url path &key credentials)
  (:documentation "Clone a repository from URL to PATH. CREDENTIALS ")
  (:method ((url string) (path pathname) &key credentials)
    (clone-repository url (namestring path) :credentials credentials))
  (:method ((url string) (path string) &key credentials)
    (with-foreign-object (repository-ref :pointer)
      (%git-clone repository-ref url path (make-instance 'clone-options :credentials credentials))
      (make-instance 'repository
                     :pointer (mem-ref repository-ref :pointer)
                     :free-function #'git-repository-free))))
