from rest_framework import permissions


class IsOwnerOrChris(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object or superuser
    'chris' to modify/edit it.
    """

    def has_object_permission(self, request, view, obj):
        # Read and write permissions are only allowed to
        # the owner and superuser 'chris'.
        return obj.owner == request.user or request.user.username == 'chris'
    

class IsFeedOwnerOrChris(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object or superuser
    'chris' to modify/edit it.
    """

    def has_object_permission(self, request, view, obj):
        # Read and write permissions are only allowed to
        # owners and superuser 'chris'.

        return (request.user in obj.owner.all()) or request.user.username == 'chris'


class IsRelatedFeedOwnerOrChris(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object or superuser
    'chris' to modify/edit it.
    """

    def has_object_permission(self, request, view, obj):
        # Read and write permissions are only allowed to
        # the owner and superuser 'chris'.
        for feed in obj.feed.all():
            if request.user == feed.owner:
                return True     
        return request.user.username == 'chris'


class IsOwnerOrChrisOrReadOnly(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object to edit it.
    """

    def has_object_permission(self, request, view, obj):
        # Read permissions are allowed to any request,
        # so we'll always allow GET, HEAD or OPTIONS requests.
        if request.method in permissions.SAFE_METHODS:
            return True

        # Write permissions are only allowed to the owner of the snippet.
        return obj.owner == request.user or request.user.username == 'chris'