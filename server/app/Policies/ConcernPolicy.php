<?php

namespace App\Policies;

use App\Models\Concern;
use App\Models\User;

/**
 * Object-level authorization (prevents IDOR): knowing a concern's ID is
 * not enough to read it.
 */
class ConcernPolicy
{
    public function view(User $user, Concern $concern): bool
    {
        return $user->isAdmin() || $concern->user_id === $user->id;
    }

    /** Only complaints have a conversation, limited to their owner and admins. */
    public function message(User $user, Concern $concern): bool
    {
        return $concern->type === 'Complaint' && $this->view($user, $concern);
    }

    public function update(User $user, Concern $concern): bool
    {
        return $user->isAdmin();
    }
}
