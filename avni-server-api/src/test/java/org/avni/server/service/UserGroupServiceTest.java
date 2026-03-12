package org.avni.server.service;

import org.avni.server.dao.UserGroupRepository;
import org.avni.server.domain.CHSEntity;
import org.avni.server.domain.User;
import org.avni.server.domain.UserContext;
import org.avni.server.framework.security.UserContextHolder;
import org.joda.time.DateTime;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class UserGroupServiceTest {
    @Mock private UserGroupRepository userGroupRepository;
    private UserGroupService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new UserGroupService(userGroupRepository);
    }
    
    @Test
    public void testIsNonScopeEntityChanged() {
        UserContext userContext = mock(UserContext.class);
        User user = mock(User.class);
        when(userContext.getUser()).thenReturn(user);
        when(user.getId()).thenReturn(1L);
        UserContextHolder.create(userContext);
        
        DateTime dateTime = DateTime.now();
        when(userGroupRepository.existsByUserIdAndLastModifiedDateTimeGreaterThan(1L, CHSEntity.toDate(dateTime)))
            .thenReturn(true);
        
        assertTrue(service.isNonScopeEntityChanged(dateTime));
    }
}
