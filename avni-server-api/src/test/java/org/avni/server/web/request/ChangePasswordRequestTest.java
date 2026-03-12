package org.avni.server.web.request;

import org.junit.Test;
import static org.junit.Assert.*;

public class ChangePasswordRequestTest {
    @Test
    public void testGettersAndSetters() {
        ChangePasswordRequest request = new ChangePasswordRequest();
        assertNull(request.getNewPassword());
        
        request.setNewPassword("newPass123");
        assertEquals("newPass123", request.getNewPassword());
        
        request.setNewPassword(null);
        assertNull(request.getNewPassword());
    }
}
