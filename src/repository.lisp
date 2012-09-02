;;; -*- Mode: Lisp; Syntax: COMMON-LISP; Base: 10 -*-

;; cl-git an Common Lisp interface to git repositories.
;; Copyright (C) 2011-2012 Russell Sim <russell.sim@gmail.com>
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

(defparameter *git-repository* nil
  "A global that stores a pointer to the current Git repository.")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Low-level interface
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; Git Repositories

(defctype git-repository-index :pointer) ;; TODO move to index.

;;; Git Config
(defcfun ("git_repository_init" %git-repository-init)
    :int
  (repository :pointer)
  (path :string)
  (bare :boolean))

(defcfun ("git_repository_open" %git-repository-open)
    %return-value
  (repository :pointer)
  (path :string))

(defcfun ("git_repository_free" git-repository-free)
    :void
  (repository %repository))

(defcfun ("git_repository_config" %git-repository-config)
    %return-value
  (out :pointer)
  (repository %repository))

(defcfun ("git_repository_index" %git-repository-index)
    %return-value
  (index :pointer)
  (repository %repository))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Highlevel Interface
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defclass repository (git-pointer) ())


(defun git-repository-init (path &optional bare)
  "Init a new Git repository.  A positive value for BARE init a bare
repository.  Returns the path of the newly created Git repository."
  (with-foreign-object (repo :pointer)
    (%git-repository-init repo (namestring path) bare)
    (git-repository-free (mem-ref repo :pointer))
    path))


(defun git-repository-open (path)
  "Open an existing repository and set the global *GIT-REPOSITORY*
variable to the open repository.  If the PATH contains a .git
directory it will be opened instead of the specified path.

TODO Simplify this function to rely on libgit2."
  (assert (null-or-nullpointer *git-repository-index*))
  (assert (null-or-nullpointer *git-repository*))
  (with-foreign-object (repository-ref :pointer)
    (let ((path (or (cl-fad:directory-exists-p
                     (merge-pathnames
                      #p".git/"
                      (cl-fad:pathname-as-directory path)))
                    (truename path))))
      (%git-repository-open repository-ref (namestring path))
      (make-instance 'repository 
		     :pointer (mem-ref repository-ref :pointer)
		     :free-function #'git-repository-free))))


(defun ensure-repository-exist (path &optional bare)
  "Open a repository at location, if the repository doesn't exist
create it.  BARE is an optional argument if specified and true, the newly
created repository will be bare."
  (handler-case
      (progn
        (git-repository-open path)
        path)
    (git-error ()
      ;; TODO should catch error 5 not all errors.
      (git-repository-init path bare)
      path)))

(defun git-repository-config ()
  "Return the config object of the current open repository."
  (assert (not (null-or-nullpointer *git-repository*)))
  (with-foreign-object (config :pointer)
    (%git-repository-config config *git-repository*)
    (mem-ref config :pointer)))


(defmacro with-repository ((path) &body body)
  "Evaluates the body with *GIT-REPOSITORY* bound to a newly opened
repositony at path."
  `(let ((*git-repository* (git-repository-open ,path)))
     (unwind-protect 
	  (progn 
	    ,@body)
       (git-free *git-repository*))))
